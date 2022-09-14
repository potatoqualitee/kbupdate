update kb set SupportedProducts = replace(SupportedProducts," Upgrade & Servicing Drivers", "") where SupportedProducts like '% Upgrade & Servicing Drivers%';
update kb set SupportedProducts = replace(SupportedProducts," Servicing Drivers", "") where SupportedProducts like '% Servicing Drivers%';
update kb set SupportedProducts = replace(SupportedProducts,", Datacenter Edition", " Datacenter Edition") where SupportedProducts like '%, Datacenter Edition%';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 version 1809 and later, Windows 10 version 1809 and later", "") where SupportedProducts like '%Windows 10 version 1809 and later, Windows 10 version 1809 and later%';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 S version 1809 and later, Windows 10 S version 1809 and later,", "Windows 10 S version 1809 and later") where SupportedProducts = 'Windows 10 S version 1809 and later, Windows 10 S version 1809 and later,';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 version 1903 and later, Windows 10 version 1903 and later", "Windows 10 version 1903 and later") where SupportedProducts = 'Windows 10 version 1903 and later, Windows 10 version 1903 and later';
update kb set SupportedProducts = replace(SupportedProducts,", SmartSetup", "") where SupportedProducts like '%, SmartSetup%';
update kb set SupportedProducts = replace(SupportedProducts,", Definition Updates for HTTP Malware Inspection", "") where SupportedProducts like '%, Definition Updates for HTTP Malware Inspection%';
update kb set SupportedProducts = replace(SupportedProducts,"Update Rollups, ", "") where SupportedProducts like '%Update Rollups%';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 S version 1903 and later, Windows 10 S version 1903 and later, Windows 10 version 1903 and later, Windows 10 version 1903 and later", "Windows 10 S version 1903 and later, Windows 10 version 1903 and later") where SupportedProducts = 'Windows 10 S version 1903 and later, Windows 10 S version 1903 and later, Windows 10 version 1903 and later, Windows 10 version 1903 and later';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 S version 1809 and later, Windows 10 S version 1809 and later, ", "Windows 10 S version 1809 and later") where SupportedProducts = 'Windows 10 S version 1809 and later, Windows 10 S version 1809 and later, ';
update kb set SupportedProducts = replace(SupportedProducts,", Windows Server 2019 and later, Windows Server 2019 and later", "Windows Server 2019 and later") where SupportedProducts = ', Windows Server 2019 and later, Windows Server 2019 and later';
update kb set SupportedProducts = replace(SupportedProducts,"Critical Updates, ", "") where SupportedProducts like '%Critical Updates, %';
update kb set SupportedProducts = replace(SupportedProducts,"Security Updates, ", "") where SupportedProducts like '%Security Updates, %';
update kb set SupportedProducts = replace(SupportedProducts,"Service Packs, ", "") where SupportedProducts like '%Service Packs, %';
update kb set SupportedProducts = replace(SupportedProducts,"Security Updates, Updates, ", "") where SupportedProducts like '%Security Updates, Updates, %';
update kb set SupportedProducts = replace(SupportedProducts,"Windows 10 version 1903 and later, Windows 10 S version 1903 and later, Windows 10 S version 1903 and later, Windows 10 version 1903 and later", "Windows 10 version 1903 and later, Windows 10 S version 1903 and later") where SupportedProducts = 'Windows 10 version 1903 and later, Windows 10 S version 1903 and later, Windows 10 S version 1903 and later, Windows 10 version 1903 and later';
update kb set SupportedProducts = replace(SupportedProducts,", ", "|") where SupportedProducts like '%, %';

update kb set RequestsUserInput = "No" where RequestsUserInput = 0;
update kb set NetworkRequired = "No" where NetworkRequired = 0;
update kb set ExclusiveInstall = "No" where ExclusiveInstall = 0;
update kb set MSRCSeverity = null where MSRCSeverity = "n/a";

update kb set Architecture = null where Architecture = "n/a";
update kb set Architecture = "x64" where Architecture LIKE '%x64%';
update kb set Architecture = "x64" where Architecture LIKE '%AMD64%';
update kb set Architecture = "x64" where Architecture LIKE '%64%bit%';
update kb set Architecture = "ARM64" where Architecture LIKE '%ARM64%';
update kb set Architecture = "ARM32" where Architecture LIKE '%ARM%based%';
update kb set Architecture = "ARM32" where Architecture LIKE '%ARM32%';
update kb set Architecture = "x86" where Architecture LIKE '%x86%';
update kb set Architecture = "x86" where Architecture LIKE '%32%bit%';
update kb set Architecture = null where architecture NOT IN ('x64','x86','IA64','ARM64','ARM','ARM32');

DELETE FROM Link
WHERE EXISTS (
  SELECT 1 FROM Link p2
  WHERE Link.UpdateId = p2.UpdateId
  AND Link.Link = p2.Link
  AND Link.rowid > p2.rowid
);


delete FROM SupersededBy
WHERE EXISTS (
  SELECT 1 FROM SupersededBy p2
  WHERE SupersededBy.UpdateId = p2.UpdateId
  AND SupersededBy.Kb = p2.Kb
  AND SupersededBy.rowid > p2.rowid
);


delete FROM Supersedes
WHERE EXISTS (
  SELECT 1 FROM Supersedes p2
  WHERE Supersedes.UpdateId = p2.UpdateId
  AND Supersedes.Kb = p2.Kb
  AND Supersedes.rowid > p2.rowid
);

/*
select distinct(SupportedProducts) from kb where SupportedProducts like '%|%' order by SupportedProducts;
select count(*) from kb where MSRCNumber is null;
select count(*) from kb where Classification like '%security%' and MSRCNumber is NULL
select * from kb where Classification like '%security%'
and MSRCNumber is NULL and MSRCSeverity is NULL;
select * from Link order by UpdateId;
select DISTINCT UpdateId, Link FROM Link;
select count(*) from link;
select UpdateId from link group;
select * from kb where title like '%KB2992080%';
select * from kb where description like '% (MS%';
*/