provider "packet" {
  auth_token = "${var.packet_api_key}"
}

resource "packet_device" "dcos_bootstrap" {
  hostname = "${format("${var.dcos_cluster_name}-bootstrap-%02d", count.index)}"

  operating_system = "coreos_stable"
  plan             = "${var.packet_boot_type}"
  connection {
    user = "core"
    private_key = "${file("${var.dcos_ssh_key_path}")}"
  }
  user_data     = "#cloud-config\n\nmanage_etc_hosts: \"localhost\"\nssh_authorized_keys:\n  - \"${file("${var.dcos_ssh_public_key_path}")}\"\n"
  facility      = "${var.packet_facility}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"
  provisioner "local-exec" {
    command = "rm -rf ./do-install.sh"
  }
  provisioner "local-exec" {
    command = "echo BOOTSTRAP=\"${packet_device.dcos_bootstrap.network.0.address}\" >> ips.txt"
  }
  provisioner "local-exec" {
    command = "echo CLUSTER_NAME=\"${var.dcos_cluster_name}\" >> ips.txt"
  }
  provisioner "remote-exec" {
  inline = [
    "wget -q -O dcos_generate_config.sh -P $HOME ${var.dcos_installer_url}",
    "mkdir $HOME/genconf"
    ]
  }
  provisioner "local-exec" {
    command = "./make-files.sh"
  }
  provisioner "local-exec" {
    command = "sed -i -e '/^- *$/d' ./config.yaml"
  }
  provisioner "file" {
    source = "./ip-detect"
    destination = "$HOME/genconf/ip-detect"
  }
  provisioner "file" {
    source = "./config.yaml"
    destination = "$HOME/genconf/config.yaml"
  }
  provisioner "remote-exec" {
    inline = ["sudo bash $HOME/dcos_generate_config.sh",
              "docker run -d -p 4040:80 -v $HOME/genconf/serve:/usr/share/nginx/html:ro nginx 2>/dev/null",
              "docker run -d -p 2181:2181 -p 2888:2888 -p 3888:3888 --name=dcos_int_zk jplock/zookeeper 2>/dev/null"
              ]
  }
}

resource "packet_device" "dcos_master" {
  hostname = "${format("${var.dcos_cluster_name}-master-%02d", count.index)}"
  operating_system = "coreos_stable"
  plan             = "${var.packet_master_type}"

  count         = "${var.dcos_master_count}"
  user_data     = "#cloud-config\n\nmanage_etc_hosts: \"localhost\"\nssh_authorized_keys:\n  - \"${file("${var.dcos_ssh_public_key_path}")}\"\n"
  facility      = "${var.packet_facility}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"
  connection {
    user = "core"
    private_key = "${file("${var.dcos_ssh_key_path}")}"
  }
  provisioner "local-exec" {
    command = "rm -rf ./do-install.sh"
  }
  provisioner "local-exec" {
    command = "echo ${format("MASTER_%02d", count.index)}=\"${self.network.0.address}\" >> ips.txt"
  }
  # FEATURE BEGIN: Integration of "Calico" into "DC/OS" for use with "Docker". 
  # Capture the IP of the masters in the new variable "ETCD_IP_XX" in case it is necessary to use later
  provisioner "local-exec" {
    command = "echo ${format("ETCD_IP_%02d", count.index)}=\"${self.network.0.address}\" >> ips.txt"
  }
  # FEATURE END: Integration of "Calico" into "DC/OS" for use with "Docker".
  provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }
  provisioner "file" {
    source = "./do-install.sh"
    destination = "/tmp/do-install.sh"
  }
  provisioner "remote-exec" {
    inline = "bash /tmp/do-install.sh master"
  }
  # FEATURE BEGIN: Integration of "Calico" into "DC/OS" for use with "Docker". 
  # Requirement 1 for Calico with Mesos. Install etcd as Docker container.
  provisioner "remote-exec" {
    inline = [
      "echo \"[INFO]: **************************************************\"",
      "echo \"[INFO]: * Install and run etcd in the Docker container: BEGIN\"",
      "echo \"[INFO]: * ---------------------------------\"",
      "${count.index == 0 ? "echo \"[INFO]: * Install \\etcd in ${format("MASTER_%02d", count.index)}\"" : "echo \"[WARNING]: * This is not MASTER_00.\"" }",
      "${count.index == 0 ? "docker run --detach --net=host --name etcd quay.io/coreos/etcd:v2.0.11 --advertise-client-urls \"http://${self.network.2.address}:2379\" --listen-client-urls \"http://${self.network.2.address}:2379,http://127.0.0.1:2379\" 2>/dev/null" : "echo \"[WARNING]: * Not install \\etcd in ${format("MASTER_%02d", count.index)} because this is not MASTER_00\""}",
      "echo \"[INFO]: * ---------------------------------\"",
      "echo \"[INFO]: * Install and run etcd in the Docker container: END\"",
      "echo \"[INFO]: **************************************************\"",
    ]
  }
  # FEATURE END: Integration of "Calico" into "DC/OS" for use with "Docker". 
}

resource "packet_device" "dcos_agent" {
  hostname = "${format("${var.dcos_cluster_name}-agent-%02d", count.index)}"
  depends_on = ["packet_device.dcos_bootstrap"]
  operating_system = "coreos_stable"
  plan             = "${var.packet_agent_type}"

  count         = "${var.dcos_agent_count}"
  user_data     = "#cloud-config\n\nmanage_etc_hosts: \"localhost\"\nssh_authorized_keys:\n  - \"${file("${var.dcos_ssh_public_key_path}")}\"\n"
  facility      = "${var.packet_facility}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"
  connection {
    user = "core"
    private_key = "${file("${var.dcos_ssh_key_path}")}"
  }
  provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }
  provisioner "file" {
    source = "do-install.sh"
    destination = "/tmp/do-install.sh"
  }
  provisioner "remote-exec" {
    inline = "bash /tmp/do-install.sh slave"
  }
  # FEATURE BEGIN: Integration of "Calico" into "DC/OS" for use with "Docker". 
  # Requirement 2 for Calico with Mesos.
  # Calico and Calicoctl install.
    provisioner "file" {
    source = "do-install-trace-env.sh"
    destination = "/tmp/do-install-trace-env.sh"
  }

  provisioner "file" {
    source = "do-install-calico-by-user.sh"
    destination = "/tmp/do-install-calico-by-user.sh"
  }

  provisioner "file" {
    source = "do-install-calico-by-root.sh"
    destination = "/tmp/do-install-calico-by-root.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/do-install-trace-env.sh",
      "chmod +x /tmp/do-install-calico-by-user.sh",
      "chmod +x /tmp/do-install-calico-by-root.sh",
      "bash /tmp/do-install-calico-by-user.sh",
      "sudo bash /tmp/do-install-calico-by-root.sh ${packet_device.dcos_master.network.2.address}"
    ]
  }
  # FEATURE END: Integration of "Calico" into "DC/OS" for use with "Docker". 
}

resource "packet_device" "dcos_public_agent" {
  hostname = "${format("${var.dcos_cluster_name}-public-agent-%02d", count.index)}"
  depends_on = ["packet_device.dcos_bootstrap"]
  operating_system = "coreos_stable"
  plan             = "${var.packet_agent_type}"

  count         = "${var.dcos_public_agent_count}"
  user_data     = "#cloud-config\n\nmanage_etc_hosts: \"localhost\"\nssh_authorized_keys:\n  - \"${file("${var.dcos_ssh_public_key_path}")}\"\n"
  facility      = "${var.packet_facility}"
  project_id    = "${var.packet_project_id}"
  billing_cycle = "hourly"
  connection {
    user = "core"
    private_key = "${file("${var.dcos_ssh_key_path}")}"
  }
  provisioner "local-exec" {
    command = "while [ ! -f ./do-install.sh ]; do sleep 1; done"
  }
  provisioner "file" {
    source = "do-install.sh"
    destination = "/tmp/do-install.sh"
  }
  provisioner "remote-exec" {
    inline = "bash /tmp/do-install.sh slave_public"
  }
  # FEATURE BEGIN: Integration of "Calico" into "DC/OS" for use with "Docker". 
  # Requirement 2 for Calico with Mesos.
  # Calico and Calicoctl install.
    provisioner "file" {
    source = "do-install-trace-env.sh"
    destination = "/tmp/do-install-trace-env.sh"
  }

  provisioner "file" {
    source = "do-install-calico-by-user.sh"
    destination = "/tmp/do-install-calico-by-user.sh"
  }

  provisioner "file" {
    source = "do-install-calico-by-root.sh"
    destination = "/tmp/do-install-calico-by-root.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/do-install-trace-env.sh",
      "chmod +x /tmp/do-install-calico-by-user.sh",
      "chmod +x /tmp/do-install-calico-by-root.sh",
      "bash /tmp/do-install-calico-by-user.sh",
      "sudo bash /tmp/do-install-calico-by-root.sh ${packet_device.dcos_master.network.2.address}"
    ]
  }
  # FEATURE END: Integration of "Calico" into "DC/OS" for use with "Docker". 
}
