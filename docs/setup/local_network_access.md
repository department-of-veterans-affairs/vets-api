## Local Network Access

These changes will work for accessing a local deploy on another device on the same network.

1. Find the IP of the machine running vets-api and vets-website, i.e `192.168.x.x`. [The IP of the machine may look like `10.0.x.x` or `172.16.x.x` instead](https://en.wikipedia.org/wiki/Private_network#Private_IPv4_addresses)
   1. Mac
      1. System Preferences > Network
      1. Click the connection you are using to connect to the internet
      1. Look for `Status`, underneath the laptop's IP address will be listed, i.e `192.168.x.x`
   1. Windows - https://support.microsoft.com/en-us/help/4026518/windows-10-find-your-ip-address
1. [Run vets-website so that devices on your local network can access it](https://github.com/department-of-veterans-affairs/vets-website/#more-commands)

   ```
   yarn watch --env.host 0.0.0.0 --env.public 198.162.x.x:3001
   ```

1. In `settings.local.yml` 
    1. Add `http://192.168.x.x:3000` and `http://192.168.x.x:3001` to `web_origin`
    1. Add `"192.168.x.x"` to `virtual_hosts`
    1. Set `virtual_host_localhost` to `192.168.x.x`
    
   ```
   # For CORS requests; separate multiple origins with a comma
   web_origin: http://192.168.x.x:3000, http://192.168.x.x:3001

   virtual_hosts: ["127.0.0.1", "localhost", "192.168.x.x"]
   virtual_host_localhost: 192.168.x.x
   ```
1. Make sure to rebuild vets-api before starting

   ```
   make rebuild; 
   make up;
   ```
   
1. From a device on the same network go to `192.168.x.x:3001`
