
Check MK list of check
----------------
 
VDP Jobs lidt snd status (check_VDP_jobs.sh)
---

1. install script in VDP appliance: /usr/lib/check_mk_agent/plugins
2. /etc/sudoers:
   check_mk ALL = (root) NOPASSWD: /usr/local/avamar/bin/mccli
3. disable VDP firewall for CheckMK port
<br>
for VDP appliance maintenance put all services "VDP" of affected VMs in check_mk Downtime
<br>
- scripts generates one check per VM (all that are protected by jobs of this local appliance)<br>
- states:<br>
  OK:   - check age less than 5min<br>
        - and - errorcode for last VM backup is 0<br>
        - and - last backup not older 90000secs (25h)<br>
  WARN: - last backup older 90000secs (25h)<br>
  CRIT  - last backup older 176400sec (49h)<br>
        - or - errorcode for last VM backup is not 0<br>
  UNKN: - check age older 5min<br>
- perfstat:<br>
        - transferred bytes<br>
        - duration in seconds<br>
<br>
- example status detail:<br>
        OK - vSphere Data Protection Backup, VM: de-bx-srv-1009, Appliance: de-bx-srv-1027, last run: 2017-01-05 18:36 CET (status: Completed, transferred 1.4% of 73.5GB)<br>
- uses avamar cli:<br>
<br>
mccli activity show<br>
,23000,CLI command completed successfully.<br>
D               Status    Error Code Start Time           Elapsed     End Time             Type             Progress Bytes New Bytes Client         Domain<br>
<br>

Check MK Collect script for VDP Jobs  (vmvdp)
---
install script in checkMK server: /omd/versions/default/share/check_mk/checks/

<br>
<br>
fell free to use and correct them,
<br>
Thanks.

