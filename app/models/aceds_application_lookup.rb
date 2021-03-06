require 'singleton'

class AcedsApplicationLookup
  include Singleton

  attr_accessor :provider

  def initialize
    @provider = AmqpSource
  end

  def search_aceds_app(person_demographics)
    provider.search_aceds_app person_demographics
  end

  def self.slug!
    instance.provider = SlugSource
  end

  def self.search_aceds_app(person_demographics)
    instance.search_aceds_app(person_demographics)
  end

  class AmqpSource
    def self.search_aceds_app(person_demographics)
      request_result = nil
      retry_attempt = 0
      while (retry_attempt < 3) && request_result.nil?
        request_result = Acapi::Requestor.request("account_management.check_existing_aceds_account", person_demographics, 2)
        retry_attempt += 1
      end
      request_result.stringify_keys["return_status"]
    end
  end

  class SlugSource
    def self.search_aceds_app(*)
      302
    end
  end
end

AcedsApplicationLookup.slug! unless Rails.env.production?
