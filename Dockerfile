# Basing the Dockerfile on the official PostgreSQL image
FROM postgres:17

# Creating dev environment for extension development
RUN mkdir /extension \
 && apt update \
 && apt install -y build-essential

# Copying the extension source code into the container
# This will allow us to compile the extension immediately
COPY ./src /extension

# Compiling the extension
RUN make install

# This enables us to use psql cli w/o pwd prompt
ENV PGUSER=dev