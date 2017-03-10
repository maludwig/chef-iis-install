#
# Cookbook Name:: learn_chef_iis
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

require 'json'

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

query = Chef::Search::Query.new
app = query.search(:aws_opsworks_app, "type:other").first
db_arn = app[0][:data_sources][0][:arn]
db_fqdn = db_arn.split(":")[-1] + ".cj5atnrr02kw.us-west-2.rds.amazonaws.com"
    s3region = app[0][:environment][:S3REGION]
    s3bucket = app[0][:environment][:BUCKET]
    s3filename = app[0][:environment][:FILENAME]

ruby_block "download-objects" do
  block do
    require 'aws-sdk'
    Aws.use_bundled_cert!

    s3_client = Aws::S3::Client.new(region: s3region)
    s3_client.get_object(
      bucket: s3bucket,
      key: s3filename,
      response_target: buildpath
      )
    s3_client.get_object(
      bucket: s3bucket,
      key: 'WebDeploy_amd64_en-US.msi',
      response_target: deploydir + '\WebDeploy_amd64_en-US.msi'
      )
  end
  action :run
  guard_interpreter :powershell_script
  not_if "Test-Path " + buildpath
end

powershell_script 'Unzip primary build artefact' do
  code '
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("%s", "%s")
  ' % [buildpath, extractdir]
  guard_interpreter :powershell_script
  not_if "Test-Path " + extractdir
end

template extractdir + '\FvApi2.SetParameters.xml' do
  source 'FvApi2.SetParameters.xml.erb'
  variables(
    :dbfqdn => db_fqdn
  )
end
