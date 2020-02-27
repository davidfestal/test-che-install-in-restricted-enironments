FROM docker.io/library/registry:2.6.2
USER 0
RUN chmod -R g=u /etc /usr /tmp /var /root /home /bin .dockerenv entrypoint.sh /lib /sbin

USER 10001

