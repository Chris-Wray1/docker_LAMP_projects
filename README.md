# Docker LAMP Projects
This is still a little crude (currently only tested with Bash/Linux), and intended to automate the creation of docker containers with linked sub-folders.

It utilises a simple config file to pass the setup details into Docker Compose, using one or moe "container" sections in the following format
```
[container name]
webport = 82
sqlport = 3308
DBrootPWD = 'Password1'
DBuser = 'dbuser'
DBuserPWD = 'Password2'
```
Each line of the section needs to be included, and the does the following ->
```
[container name]  --> This will become the main reference used for container, volumes, images an dbuilds within Docker
webport           --> This is the port number exposed to localhost for Apache
sqlport           --> Similarly, this is the post eposed to localhost for MySQL
DBrootPWD         --> This is the MySQL password for the root user
DBuser            --> This is the default user for the MySQL databasse
DBuserPWD         --> This is the passwrod for the default user to login to MySQL
```

The config file can contain multiple sections and each section will create a container

Each container will have an instance of Apache with PHP running on a Debian server, with a MySQL DB

To use this setup, clone the repo, ensure that the setup.sh file is executable, edit the container.config file and run setup.sh from a command line.
