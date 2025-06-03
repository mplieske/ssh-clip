#!/usr/bin/env bash

function _ssh_clip_format() {
    if [ -z "$1" ]; then
        xargs -I {} echo "$(date +"%Y-%m-%d %T.%3N") [INFO] - {}"
    elif [[ "$1" == "-e" ]]; then
        xargs -I {} echo "$(date +"%Y-%m-%d %T.%3N") [ERROR] - {}"
    else
        echo "ERROR: _ssh_clip_format: Invalid argument '${1}'" >> /dev/stderr
    fi
}

function _ssh_clip_log() {
    _ssh_clip_format | tee -a /var/log/ssh-clip/ssh-clip.log
}

function _ssh_clip_err() {
    _ssh_clip_format -e | tee -a /var/log/ssh-clip/error.log
}

function ssh-clip() {
    if ! xclip -version; then
        echo "xclip required but is not installed." | _ssh_clip_err
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo "ssh-clip listens to a given port on the local host, to get clipboard content. After that an ssh connection with port redirection is opened."
                echo ""
                echo "ssh-clip [options]"
                echo ""
                echo "Options:"
                echo "-n|--hostname       Hostname or IP of the host to connect to. (mnadatory)"
                echo "-r|--remote-port    Port on the remote host to use for clipboard redirection. (optional)"
                echo "                    At least one of --local-port and --remote-port has to be used."
                echo "                    Either option will default to the given one if not provided."
                echo "-l|--local-port     Port on the local host to use for clipboard redirection. (optional)"
                echo "                    At least one of --local-port and --remote-port has to be used."
                echo "                    Either option will default to the given one if not provided."
                echo "-u|--user           Username to login with on the remote host. (optional)"
                return 0
                ;;

            -r|--remote-port)
                remote_port="${2}"
                echo "remote_port: '${remote_port}'" | _ssh_clip_log
                shift
                shift
                ;;

            -l|--local-port)
                local_port="${2}"
                echo "local_port: '${local_port}'" | _ssh_clip_log
                shift
                shift
                ;;

            -n|--hostname)
                hostname="${2}"
                echo "hostname: '${hostname}'" | _ssh_clip_log
                shift
                shift
                ;;

            -u|--user)
                user="${2}"
                echo "user: '${user}'" | _ssh_clip_log
                shift
                shift
                ;;

            *)
                echo "Unknown option '${1}'." | _ssh_clip_err
                return 1
                ;;
        esac
    done

    if [ -z "${hostname}" ]; then
        echo "Missing argument '-n|--hostname'" | _ssh_clip_err
        return 1
    fi

    if [ -z "${remote_port}" ] && [ -z "${local_port}" ]; then
        echo "At leas one of the following options must be provided: -r/--remote-port, -l/--local-port." | _ssh_clip_err
        return 1
    fi

    if [ -z "${local_port}" ]; then
        local_port="${remote_port}"
        echo "local_port: '${local_port}'" | _ssh_clip_log
    fi

    if [ -z "${remote_port}" ]; then
        remote_port="${local_port}"
        echo "remote_port: '${remote_port}'" | _ssh_clip_log
    fi

    echo "while nc -l \"${local_port}\" | xclip -i -sel p -f | xclip -i -sel c ; do sleep 0; done &" | _ssh_clip_log
    while nc -l "${local_port}" | xclip -i -sel p -f | xclip -i -sel c ; do sleep 0; done &
    echo "job id: $(jobs -l | grep "while nc -l \"${local_port}\"" | grep -Po '^\[[0-9]+\]')" | _ssh_clip_log

    if [ -z "${user}" ]; then
        hostname_connection_string="${hostname}"
    else
        hostname_connection_string="${user}@${hostname}"
    fi

    IFS='' read -r -d '' remote_setup <<EOF
mkdir -p ~/.local/bin/
if ! echo \$PATH | grep -Pq "(\$HOME/.local/bin:|:\$HOME/.local/bin)"; then
    export PATH="${PATH}:~/.local/bin/"
fi
cat > ~/.local/bin/ssh-kopy <<EFF
#!/usr/bin/env bash
nc localhost ${remote_port}
EFF

chmod +x ~/.local/bin/ssh-kopy

bash
EOF

    port_redirection_string="${remote_port}:localhost:${local_port}"
    echo "ssh -R \"${port_redirection_string}\" \"${hostname_connection_string}\"" | _ssh_clip_log
    ssh -R "${port_redirection_string}" -t "${hostname_connection_string}" "${remote_setup}"

    echo "Teardown." | _ssh_clip_log
    echo "ssh -t \"${hostname_connection_string}\" \"rm ~/.local/bin/ssh-kopy\"" | _ssh_clip_log
    ssh -t "${hostname_connection_string}" "rm ~/.local/bin/ssh-kopy"

    kill %$(jobs -l | grep "while nc -l \"${local_port}\"" | grep -Po '^\[[0-9]+\]' | grep -Po '[0-9]+')
    return 0
}

