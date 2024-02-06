FROM dart:3.2.6

# Install required packages
RUN apt-get update && apt-get install -y \
    fish \
    git \
    openssh-client \
    gnupg \
    curl \
    wget \
    # Remove APT cache
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
# Set the default user to $USERNAME
USER $USERNAME

# Set the default shell to fish
SHELL ["/usr/bin/fish", "-c"]

# Set the default working directory to /workspace
WORKDIR /workspace

# Set the default command to run when the container starts
CMD ["fish"]

# Add Dart pub cache to PATH
ENV PATH="/home/${USERNAME}/.pub-cache/bin:${PATH}"

# Install mono_repo
RUN dart pub global activate mono_repo
