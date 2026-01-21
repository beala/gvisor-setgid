FROM ubuntu:26.04

RUN useradd -m testuser
RUN mkdir /opt/setgid-test
RUN chown root:testuser /opt/setgid-test
RUN chmod 2775 /opt/setgid-test