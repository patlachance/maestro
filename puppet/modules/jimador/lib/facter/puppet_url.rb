# == jimador::puppet_url
# (c) Copyright 2014 Hewlett-Packard Development Company, L.P.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

Facter.add("puppet_url") do
 confine :kernel => "Linux"
 setcode do
   if File.exist? "/usr/share/puppet-dashboard/public/robots.txt"
     if ! Facter.value("ec2_public_ipv4").nil?
        http_name = Facter.value("ec2_public_ipv4")
     else
        http_name = Facter.value("ipaddress")
     end
     Facter::Util::Resolution.exec("echo http://#{http_name}:$(egrep -lir \"puppet-dashboard\" /etc/apache2/sites-enabled/*.conf|xargs -i grep '<VirtualHost.*>' {}|awk -F'[<|>]' '{printf $2}'|awk -F':' '{printf $2}')")
   else
     Facter::Util::Resolution.exec("echo")
   end
 end
end