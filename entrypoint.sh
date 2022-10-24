#!/bin/bash
/usr/bin/ssh-keygen -t rsa -b 4096 -N "" -f /etc/ssh/ssh_host_rsa_key
/usr/sbin/sshd -D -h /etc/ssh/ssh_host_rsa_key &
/root/server