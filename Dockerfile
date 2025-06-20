FROM amazonlinux:2023

# Install dependencies
RUN dnf update -y && \
    dnf install -y git expect jq python3 python3-pip unzip expect && \
    dnf clean all

# Install AWS CLI
RUN pip3 install --upgrade awscli

# Install Amazon Q Developer CLI
# Note: Replace with the actual installation command for Amazon Q
RUN curl --proto '=https' --tlsv1.2 -sSf "https://desktop-release.q.us-east-1.amazonaws.com/latest/q-x86_64-linux.zip" -o "q.zip" && unzip q.zip  && ./q/install.sh --force --no-confirm && cp /q/bin/* /usr/local/bin/


# Set up working directory
WORKDIR /workspace

# Copy our scripts
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Default entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
