### Debugging in Docker, useful for windows developers.

These instructions assume you are using RubyMine, an IDE from JetBrains.
You can get it here:
https://www.jetbrains.com/ruby/

When developing with Windows you need to ensure that your clone pulled down all your files with unix style line endings.
To check, from git bash use the *file* utility:
```
$ file docker-compose.yml
docker-compose.yml: ASCII text
```
The above output is good. If you see:
```
$ file docker-compose.yml
docker-compose.yml: ASCII text, with CRLF line terminators
```
That is bad.  You will need to re-clone and ensure you pass the test above.  There are many resources on the web that can help with this, here is one that can help:

https://www.cylindric.net/git/force-lf

The main readme describes setting up (touching) your certs. Make sure you do that.

The main docker file has the following line:
```
RUN freshclam --config-file freshclam.conf
```
Commenting out this line can save you a lot of time in the initial build if you are using fake clamscan.

In the file 'docker-entrypoint.sh at the end add this line:
rails server --binding=0.0.0.0

 docker-compose run vets-api rails server --binding=0.0.0.0

do a:
docker-compose up
This will start a full build which takes quite a while.  Eventually puma will come up and you can hit:
http://localhost:3000/v0/status

do a 
docker-compose down
b4 configuring rubymine and remove the 
rails server --binding=0.0.0.0 from the previous file.

In Ruby mine:
File -> settings -> languages and framework -> Ruby sdk and Gems
Select '+' -> 'new remote'
Choose the 'Docker Compose' radio button
Choose 'vets-api' for the service
Select OK.

Run -> debug... -> edit configurations 
Select '+' and add a new rails configuration
Accept defaults

