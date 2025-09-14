Repositiory for Terraform IAC deployment

Description of Web Server Information for EC2 Machine:

user_data = base64encode(<<-EOF
              #!/bin/bash
              # simple web app serving on 8080
              apt-get update -y
              apt-get install -y python3
              echo "Hello from $(hostname)" > /var/www/index.html
              nohup python3 -m http.server 8080 --directory /var/www >/var/log/simple_http.log 2>&1 &
              EOF
  )

Creates a simple web page: echo "Hello from $(hostname)" > /var/www/index.html
echo "Hello from $(hostname)": This part generates a line of text. The $(hostname) is a command substitution that runs the hostname command and replaces itself with the output. For example, if the server's hostname is maigation, the command becomes echo "Hello from maigation".
>: This is the redirection operator, which sends the output of the echo command to a file: in this case index.html
/var/www/index.html: This specifies the destination file. This command overwrites the main index file for a typical web server, replacing it with the new content.

Part 2: "nohup python3 -m http.server 8080 --directory /var/www >/var/log/simple_http.log 2>&1 &"
Starts a basic web server in the background: nohup python3 -m http.server 8080 --directory /var/www >/var/log/simple_http.log 2>&1 &
Definition:
nohup: This command prevents the server process from being terminated when the user logs out or closes the terminal session. nohup stands for "no hang up".
python3 -m http.server 8080 --directory /var/www: This is the command that starts the web server. It uses Python 3's built-in http.server module to serve files from the /var/www directory on port 8080.
>/var/log/simple_http.log: This redirects the server's standard output (stdout) to a log file.
2>&1: This redirects the server's standard error (stderr) to the same location as its standard output (the log file). This ensures that all output, including any error messages, is captured in one place.
&: This runs the entire command in the background, allowing the script to continue running other commands without waiting for the web server to finish.
