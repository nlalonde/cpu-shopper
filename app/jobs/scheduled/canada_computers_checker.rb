# frozen_string_literal: true

require 'net/http'

module Jobs
  class CanadaComputersChecker < ::Jobs::Scheduled

    every 5.minutes

    def execute(args = {})
      check_5950x
    end

    def check_5950x
      canada_computers_url = "https://www.canadacomputers.com/product_info.php?ajaxstock=true&itemid=183427"

      uri = URI(canada_computers_url)
      request = Net::HTTP::Get.new(uri)
      request.add_field(
        "User-Agent",
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:87.0) Gecko/20100101 Firefox/87.0"
      )
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

      json = JSON.parse(response.body)

      h = build_availability_hash(json)

      online_count = online_available(h)
      toronto_count = toronto_available(h)

      if online_count > 0 || toronto_count > 0
        notify_availability("5950x", build_availability_string(json))
      elsif other_available?(h)
        notify_availability("5950x-other", build_availability_string(json))
      end

      h
    end

    def build_availability_hash(json)
      h = {}

      (0..3).each do |i|
        lkey = i == 0 ? "loc" : "loc#{i}"
        akey = i == 0 ? "avail" : "avail#{i}"

        if location = json[lkey]
          h[location.gsub(" ", "_").downcase.to_sym] = json[akey] || "?"
        end
      end

      h
    end

    def build_availability_string(json)
      s = +""

      (0..3).each do |i|
        lkey = i == 0 ? "loc" : "loc#{i}"
        akey = i == 0 ? "avail" : "avail#{i}"

        if location = json[lkey]
          s << "#{location}: #{json[akey] || '?'}\n\n"
        end
      end

      s
    end

    def online_available(h)
      if h[:online] && h[:online] != "NO AVAILABLE"
        h[:online]
      else
        0
      end
    end

    def toronto_available(h)
      if toronto_key = h.keys.find { |k| k.to_s.include?("toronto") }
        h[toronto_key]
      else
        0
      end
    end

    def other_available?(h)
      h.keys.any? { |k| k != :all_locations && k != :online }
    end

    def notify_availability(product_name, string)
      tcf_name = "shopper-#{product_name}"

      if tcf = TopicCustomField.joins(:topic).where(name: tcf_name).last
        topic = tcf.topic
        PostCreator.create!(
          Discourse.system_user,
          topic_id: topic.id,
          raw: string,
          skip_validations: true
        )
      else
        post = SystemMessage.create_from_system_user(
          User.where(username: "neil").first,
          :shopper_found_availability,
          product_name: product_name,
          availability: string
        )
        topic = post.topic
        topic.custom_fields[tcf_name] = "1"
        topic.save
        post
      end
    end
  end
end
