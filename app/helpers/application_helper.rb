module ApplicationHelper
  module Couple
    def self.get_couple_name(couple, conn = '&')
      space = ' '
      first = couple['Registrant1FirstName'] + space + couple['Registrant1LastName']
      second = couple['Registrant2FirstName'] +
          (couple['Registrant2LastName'].present? ? space + couple['Registrant2LastName'] : '')

      first << (second.present? ? (space + conn + space + second) : '')
    end

    def self.get_couple_info(couple)
      event_date, location = couple_params(couple)

      {
          username1: "#{couple['Registrant1FirstName']} #{couple['Registrant1LastName']}",
          username2: ("#{couple['Registrant2FirstName']} #{couple['Registrant2LastName']}" unless couple['Registrant2FirstName'].nil? and couple['Registrant2LastName'].nil?),
          eventdate: event_date,
          coupleid: couple['Id'],
          location: location,
          coupleregistries: couple['CoupleRegistries']
      }
    end

    def self.get_profile_url(couple)
      {
          shortUrl: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['ShortUrl'],
          universalRegistryId: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['Id'],
          longUrl: couple['UniversalRegistryLongUrl']
      }
    end

    def self.get_location(couple)
      if /usa?/i.match couple['Country']
        location = "#{couple['City']}, #{couple['State']}"
      else
        location = "#{couple['City']}, #{couple['CountryFullName']}"
      end

      /^[\s,]+$/.match(location) ? '' : location.gsub(/^,\s|,\s$/, '')
    end

    def self.get_couple_description(couple)
      event_date, location = couple_params(couple)
      retailer_names = ApplicationHelper::Retailer.get_retailer_names couple['CoupleRegistries']
      "#{couple['Registrant1FirstName']}#{couple['Registrant2FirstName'].present? ? ' and ' + couple['Registrant2FirstName'] : ''}
          from #{ location } have registered at #{retailer_names}
          for their wedding on #{ event_date }.
          View all of the items from their registries in one beautiful list."
    end

    def self.couple_params(couple)
      event_date = Date.parse(couple['EventDate']).strftime('%B %d, %Y')
      location = get_location couple
      [event_date, location]
    end
  end

  module Retailer
    def self.get_retailer_names(registries)
      retailer_names = Array.new(registries).delete_if {|registry| registry['Retailer'].nil?}
      retailer_names = retailer_names.map {|registry| registry['Retailer']['Name']}
      parse_retailer_names(retailer_names)
    end

    def self.parse_retailer_names(retailer_names)
      if retailer_names.length < 2
        retailer_names.to_s
      else
        retailer_names.take(retailer_names.count - 1).join(', ') << ' and ' << retailer_names.at(retailer_names.count - 1)
      end
    end
  end
end
