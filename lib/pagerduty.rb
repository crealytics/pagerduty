require 'json'
require 'net/http'
require 'net/https'
require 'pagerduty/version'

class PagerdutyException < Exception
  attr_reader :pagerduty_instance, :api_response

  def initialize(instance, resp)
    @pagerduty_instance = instance
    @api_response = resp
  end
end

class Pagerduty
  attr_reader :service_key, :incident_key

  def initialize(service_key, incident_key = nil)
    @service_key = service_key
    @incident_key = incident_key
    enable!
  end

  def trigger(description, details = {})
    if enabled?
      details = {hostname: `hostname -f`.strip, process_name: $PROGRAM_NAME}.merge(details)
      resp = api_call("trigger", description, details)
      throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

      PagerdutyIncident.new @service_key, resp["incident_key"]
    end
  end

  def disable!
    @enabled = false
  end

  def enable!
    @enabled = true
  end

  def enabled?
    @enabled
  end

  # trigger or resolve the incident (identified by incident_key)
  # depending on state parameter
  def trigger_or_resolve(state, description, details = {})
    if state
      incident = get_incident @incident_key if @incident_key
      incident.resolve description if incident
    else
      trigger description, details
    end
  end

  def monitor
    begin
      ret = yield
      resolve
      ret
    rescue Exception => e
      trigger e.to_s, exception_class: e.class, stacktrace: e.backtrace
      raise
    end
  end

  def resolve(incident_key = nil, description: nil)
    if enabled?
      key = incident_key || @incident_key
      return unless key
      incident = get_incident(key)
      return unless incident
      incident.resolve description
    end
  end

  def get_incident(incident_key)
    PagerdutyIncident.new @service_key, incident_key
  end

protected
  def api_call(event_type, description, details = {})
    params = { :event_type => event_type, :service_key => @service_key, :description => description, :details => details }
    params.merge!({ :incident_key => @incident_key }) unless @incident_key == nil

    url = URI.parse("https://events.pagerduty.com/generic/2010-04-15/create_event.json")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = (url.scheme == 'https')
    rootca = '/etc/ssl/certs'
    if (File.directory?(rootca) && http.use_ssl?)
      http.ca_path = rootca
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_depth = 5
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new(url.request_uri)
    req.body = JSON.generate(params)

    res = http.request(req)
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      JSON.parse(res.body)
    else
      res.error!
    end
  end
end

class PagerdutyIncident < Pagerduty
  def initialize(service_key, incident_key)
    super service_key
    @incident_key = incident_key
  end

  def acknowledge(description, details = {})
    resp = api_call("acknowledge", description, details)
    throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

    self
  end

  def resolve(description, details = {})
    resp = api_call("resolve", description, details)
    throw PagerdutyException.new(self, resp) unless resp["status"] == "success"

    self
  end
end
