#
# Cookbook Name:: learn_chef_iis
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.
# powershell_script 'Install Web Server (IIS) and dependencies' do
#   code 'Add-WindowsFeature Web-Server,Web-WebServer,Web-Common-Http,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Health,Web-Http-Logging,Web-Performance,Web-Stat-Compression,Web-Security,Web-Filtering,Web-App-Dev,Web-Net-Ext45,Web-ASP,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Tools,Web-Mgmt-Console,NET-Framework-45-Features,NET-Framework-45-Core,NET-Framework-45-ASPNET'
#   guard_interpreter :powershell_script
#   not_if '(Get-WindowsFeature -Name Web-Server).Installed'
# end

# service 'w3svc' do
#   action [:enable, :start]
# end

# template 'c:\inetpub\wwwroot\Default.htm' do # ~FC033
#   source 'Default.htm.erb'
# end

# directory 'c:\IISSite' do
#   rights :read, 'IIS_IUSRS'
#   recursive true
# end
deploydir = 'C:\Deploy'
buildpath = deploydir + '\FvAPI2_1.0.6031.zip'
extractdir = deploydir + '\6031'

# s3region = "us-west-2"
# s3bucket = "fieldvu-deploys"
# s3filename = "test/FvAPI2_1.0.6031.zip"

chef_gem "aws-sdk" do
  compile_time false
  action :install
end

directory deploydir do
  action :create
end

ruby_block "download-object" do
  block do
    require 'aws-sdk'

    #1
    Aws.config[:ssl_ca_bundle] = 'C:\ProgramData\Git\bin\curl-ca-bundle.crt'

    #2
    query = Chef::Search::Query.new
    app = query.search(:aws_opsworks_app, "type:other").first
    s3region = app[0][:environment][:S3REGION]
    s3bucket = app[0][:environment][:BUCKET]
    s3filename = app[0][:environment][:FILENAME]

    #3
    s3_client = Aws::S3::Client.new(region: s3region)
    s3_client.get_object(bucket: s3bucket,
      key: s3filename,
      response_target: buildpath)
  end
  action :run
end

powershell_script 'Unzip primary build artefact' do
  code '
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("%s", "%s")
  ' % [buildpath, extractdir]
  guard_interpreter :powershell_script
end


require 'json'
template 'c:\inetpub\wwwroot\Default.htm' do
  source 'Default.htm.erb'
  variables(
    :nodejson => JSON.pretty_generate(node)
  )
end

file 'c:\inetpub\wwwroot\node.json' do
  content JSON.pretty_generate(node)
end
