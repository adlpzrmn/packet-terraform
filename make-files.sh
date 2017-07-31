#!/usr/bin/env bash
. ./ips.txt
# Make some config files
cat > config.yaml << FIN
bootstrap_url: http://$BOOTSTRAP:4040
cluster_name: $CLUSTER_NAME
exhibitor_storage_backend: zookeeper
exhibitor_zk_hosts: $BOOTSTRAP:2181
exhibitor_zk_path: /$CLUSTER_NAME
log_directory: /genconf/logs
master_discovery: static
master_list:
- $MASTER_00
- $MASTER_01
- $MASTER_02
- $MASTER_03
- $MASTER_04
resolvers: 
- 8.8.4.4
- 8.8.8.8
FIN

cat > ip-detect << FIN
#!/usr/bin/env bash
set -o nounset -o errexit
export PATH=/usr/sbin:/usr/bin:\$PATH
echo \$(ip addr show bond0 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
FIN

# Make a script

cat > do-install.sh << FIN
#!/usr/bin/env bash
mkdir /tmp/dcos && cd /tmp/dcos
printf "Waiting for installer to appear at Bootstrap URL"
until \$(curl -m 2 --connect-timeout 2 --output /dev/null --silent --head --fail http://$BOOTSTRAP:4040/dcos_install.sh); do
    sleep 1
done           
curl -O http://$BOOTSTRAP:4040/dcos_install.sh
sudo bash dcos_install.sh \$1
FIN
rm -rf ./ips.txt


cat > do-install-trace-env.sh << EOF
#!/usr/bin/env bash

# Script: do-install-trace-env.sh

THIS_SCRIPT_NAME=\${BASH_SOURCE[0]}

TRACE_PREFIX=

if [[ \$1  != "" ]]; then
    TRACE_PREFIX="[\$1] - ";
fi

echo "\${TRACE_PREFIX}[INFO]: **************************************************"
echo "\${TRACE_PREFIX}[INFO]: * Trace Environment: BEGIN"
echo "\${TRACE_PREFIX}[INFO]: * ---------------------------------"
echo "\${TRACE_PREFIX}[INFO]: * USER=\`whoami\`"
echo "\${TRACE_PREFIX}[INFO]: * PATH=\$PATH"
echo "\${TRACE_PREFIX}[INFO]: * PWD=\$PWD"
echo "\${TRACE_PREFIX}[INFO]: * ---------------------------------"
echo "\${TRACE_PREFIX}[INFO]: * /usr/bin/env = "
/usr/bin/env
echo "\${TRACE_PREFIX}[INFO]: * ---------------------------------"
# set
# echo "\${TRACE_PREFIX}[INFO]: * ---------------------------------"
echo "\${TRACE_PREFIX}[INFO]: * Trace Environment: END"
echo "\${TRACE_PREFIX}[INFO]: **************************************************"
EOF

cat > do-install-calico-by-user.sh << EOF
#!/usr/bin/env bash

# Script: do-install-calico-by-user.sh

THIS_SCRIPT_CURRENT_PATH=\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )
THIS_SCRIPT_NAME=\${BASH_SOURCE[0]}


\$THIS_SCRIPT_CURRENT_PATH/do-install-trace-env.sh \$THIS_SCRIPT_NAME

# export PATH for the calicoctl program for the current session
echo "[\$THIS_SCRIPT_NAME] - [INFO]: *************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * export PATH for the calicoctl program for the current session of user \"\`whoami\`\": BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

export PATH=\$PATH:/opt/calicoctl

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Exported PATH for the calicoctl program for the current session of user \"\`whoami\`\"."
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * export PATH for the calicoctl program for the current sessionof user \"\`whoami\`\": END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

# The .basrc file is a link to a file located in the read-only file system, 
# even for the root user. We will create the .bashrc file in the core user's home,
# from the linked, which serves as a skeleton, and add the export to the PATH variable 
# of the calicoctl path, so that it is at least permanent for the bash shell 
# of user core.
# For an interactive shell that is not a login shell.
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create \$HOME/.bashrc file: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

if  [[ -L \$HOME/.bashrc ]]; then
    cat \$HOME/.bashrc > \$HOME/.bashrc_temp;
    chmod u=rw,g=r,o=r \$HOME/.bashrc_temp;
    rm \$HOME/.bashrc;
    mv \$HOME/.bashrc_temp \$HOME/.bashrc;
    if [[ \$? == 0 ]]; then
        echo "[\$THIS_SCRIPT_NAME] - [INFO]: * The \"\$HOME/.bashrc\" its a symbolic link and it is create as a regular file.";
    else
        echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * The \"\$HOME/.bashrc\" its a symbolic link but it is not create as a regular file.";
    fi
else 
    echo "[\$THIS_SCRIPT_NAME] - [WARNING]: * The \"\$HOME/.bashrc\" its not a symbolic link";
fi

if  [[ -f \$HOME/.bashrc && -w \$HOME/.bashrc ]]; then
    echo "export PATH=\\\$PATH:/opt/calicoctl" >> \$HOME/.bashrc;
    if [[ \$? == 0 ]]; then
        echo "[\$THIS_SCRIPT_NAME] - [INFO]: * The file \"\$HOME/.bashrc\" was found and the path \"/opt/calicoctl\" has been added  file of the user \"\`whoami\`\".";
    else
        echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * The file \"\$HOME/.bashrc\" was found but the path \"/opt/calicoctl\" has not been added  file of the user \"\`whoami\`\".";
    fi
else 
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * The file \"\$HOME/.bashrc\" was not found or is not regular or writable file. The path \"/opt/calicoctl\" has not been added to the \"\$HOME/.bashrc\" file of the user \"\`whoami\`\" so the route will not be permanently exported to the PATH \"\`whoami\`\" system environment variable";
fi

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create \$HOME/.bashrc file: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
EOF

# FEATURE BEGIN: Integration of "Calico" into "DC/OS" for use with "Docker". 
# Requirement 2 for Calico with Mesos and calicoctl and calico install
cat > do-install-calico-by-root.sh << EOF
#!/usr/bin/env bash

# Script: do-install-calico-by-root.sh
# Should receive as an argument the IP of the storage service "etcd" used and configured
# for the docker service as "Cluster Store"

THIS_SCRIPT_CURRENT_PATH=\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )
THIS_SCRIPT_NAME=\${BASH_SOURCE[0]}

# export PATH for the calicoctl program for the current session
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * export PATH for the calicoctl program for the current session of user \"\`whoami\`\": BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

export PATH=\$PATH:/opt/calicoctl

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Exported PATH for the calicoctl program for the current session of user \"\`whoami\`\""
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * export PATH for the calicoctl program for the current session of user \"\`whoami\`\": END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

\$THIS_SCRIPT_CURRENT_PATH/do-install-trace-env.sh \$THIS_SCRIPT_NAME

# TODO: Validate input parameters

# Requeriment 2: Docker Configured with Cluster Store
# sudo sh -c 'echo -e "{\n \"cluster-store\":\"etcd://\$1:2379\"\n}\" > /etc/docker/daemon.json'
# sudo systemctl restart docker
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Docker Configured with Cluster Store: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

echo -e "{\n \"cluster-store\":\"etcd://\$1:2379\"\n}" > /etc/docker/daemon.json
systemctl restart docker

if [[ \$? == 0 ]]; then
    echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Docker is configured with Cluster Store.";
else
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * Docker is not configured with Cluster Store."
fi

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Docker Configured with Cluster Store: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

# The /usr/local/bin and similars path are read-only filesystem 
# even for the root user
# We have to use another path to install the executable file calicoctl 
# on which the root user has write permissions and is as global as possible
# to the system, that is, it is not local to the core or root user. 
# The one chosen is '/opt'
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create /opt/calicoctl path: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

mkdir /opt/calicoctl

if [[ \$? == 0 ]]; then
    echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Path /opt/calicoctl has been created.";
else
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * No path /opt/calicoctl has been created.";
fi

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create /opt/calicoctl path: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

# Idem for user root for an interactive shell that is not a login shell.
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create /root/.bashrc file: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

if [[ ! -e /root/.bashrc ]]; then
    cat /usr/share/skel/.bashrc > /root/.bashrc;
    chmod u=rw,g=r,o=r /root/.bashrc;
    if [[ \$? == 0 ]]; then
        echo "[\$THIS_SCRIPT_NAME] - [INFO]: * File /root/.bashrc has been created and changed mode.";
    else
        echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * No file /root/.bashrc has been created or unchanged mode.";
    fi
else 
    echo "[\$THIS_SCRIPT_NAME] - [WARNING]: * The \"/root/.bashrc\" exits.";
fi

if [[ -f /root/.bashrc && -w /root/.bashrc ]]; then
    echo "export PATH=\\\$PATH:/opt/calicoctl" >> /root/.bashrc;
    if [[ \$? == 0 ]]; then
        echo "[\$THIS_SCRIPT_NAME] - [INFO]: * The file \"\root/.bashrc\" was found and the path \"/opt/calicoctl\" has been added  file of the user \"\`whoami\`\".";
    else
        echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * The file \"/root/.bashrc\" was found but the path \"/opt/calicoctl\" has not been added  file of the user \"\`whoami\`\".";
    fi
else 
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * The file \"/root/.bashrc\" was not found or is not regular or writable file. The path \"opt/calicoctl\" has not been added to the \"/root/.bashrc\" file of the user \"\`whoami\`\" so the route will not be permanently exported to the PATH \"\`whoami\`\" system environment variable";
fi

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create /root/.bashrc file: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

# Idem for interactive login shell for all users, included root.
# Add sh file in /etc/profile.d path using the system wide initialization file /etc/profile
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create add_calicoctl_path.sh file with export PATH for calicoctl and add to /etc/profile.d folder: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

echo "export PATH=\\\$PATH:/opt/calicoctl" > /opt/calicoctl/add_calicoctl_path.sh
ln -s /opt/calicoctl/add_calicoctl_path.sh /etc/profile.d/calicoctl.sh

if [[ \$? == 0 ]]; then
    echo "[\$THIS_SCRIPT_NAME] - [INFO]: * File add_calicoctl_path.sh with export PATH for calicoctl has been create and added to /etc/profile.d folder.";
else
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * No file add_calicoctl_path.sh with export PATH for calicoctl has been create and added to /etc/profile.d folder.";
fi

echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Create add_calicoctl_path.sh file with export PATH for calicoctl and add to /etc/profile.d folder: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"

# Install calicoctl and components of calico
echo "[\$THIS_SCRIPT_NAME] - [INFO]: **************************************************"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Install calicoctl and calico components: BEGIN"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"

wget -O /opt/calicoctl/calicoctl https://github.com/projectcalico/calicoctl/releases/download/v1.3.0/calicoctl
chmod +x /opt/calicoctl/calicoctl
ETCD_ENDPOINTS=http://\$1:2379 calicoctl node run --node-image=quay.io/calico/node:v1.3.0

if [[ \$? == 0 ]]; then
    echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Calicoctl and calico components have been installed.";
else
    echo "[\$THIS_SCRIPT_NAME] - [ERROR]: * Calicoctl and calico components have not been installed.";
fi
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * ---------------------------------"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * Install calicoctl and calico components: END"
echo "[\$THIS_SCRIPT_NAME] - [INFO]: * *************************************************"
EOF
# FEATURE END: Integration of "Calico" into "DC/OS" for use with "Docker".





