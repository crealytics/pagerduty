require 'bundler/gem_tasks'
require 'rubygems'
require 'bundler'
require 'rake'

Bundler::GemHelper.install_tasks

module GemServerCredentials
  def self.secure_url(host_name, port=nil)
    credentials = Bundler::Settings.new[host_name]
    raise "Could not find credentials for #{host_name}. Run: bundle config #{host_name} USERNAME:PASSWORD" unless credentials
    base_url = "https://#{credentials}@#{host_name}"
    if port
      "#{base_url}:#{port}"
    else
      base_url
    end
  end
end

# Monkey patch Bundler gem_helper so we release to our gem server instead of rubygems.org
# borrowed from http://www.alexrothenberg.com/2011/09/16/running-a-private-gemserver-inside-the-firewall.html
module Bundler
  class GemHelper

    def rubygem_push(path)
      gem_server_url = GemServerCredentials.secure_url 'gemserver.camato.eu'
      sh("gem inabox '#{path}' --host #{gem_server_url}")
      Bundler.ui.confirm "Pushed #{name} #{version} to #{gem_server_url}"
    end
  end
end
