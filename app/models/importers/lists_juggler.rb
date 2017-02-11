module Importers
  class ListsJuggler

    class InvalidTournament < StandardError;
    end

    def sync_tournaments(minimum_id: nil, start_date: nil)
      uri         = URI.parse('http://lists.starwarsclubhouse.com/api/v1/tournaments')
      response    = Net::HTTP.get_response(uri)
      tournaments = JSON.parse(response.body).try(:[], 'tournaments') || []
      tournaments.sort.each do |lists_juggler_id|
        if minimum_id.nil? || lists_juggler_id >= minimum_id
          puts "[#{lists_juggler_id}]"
          tournament = Tournament.find_by(lists_juggler_id: lists_juggler_id)
          if start_date.nil? || tournament.nil? || tournament.date.nil? || tournament.date >= DateTime.parse(start_date.to_s)
            tournament ||= Tournament.new(lists_juggler_id: lists_juggler_id)
            sync_tournament(tournament)
          end
        end
      end
    end

    def sync_tournament(tournament)
      uri              = URI.parse("http://lists.starwarsclubhouse.com/api/v1/tournament/#{tournament.lists_juggler_id}")
      response         = Net::HTTP.get_response(uri)
      tournament_data  = JSON.parse(response.body).try(:[], 'tournament')
      venue_attributes = {
        name:    tournament_data['venue']['name'],
        city:    tournament_data['venue']['city'],
        state:   tournament_data['venue']['state'],
        country: tournament_data['venue']['country'],
        lat:     tournament_data['venue']['lat'],
        lon:     tournament_data['venue']['lon'],
      }
      if tournament_data.present?
        tournament.assign_attributes({
                                       name:            tournament_data['name'],
                                       date:            tournament_data['date'],
                                       format:          tournament_data['format'],
                                       round_length:    tournament_data['round_length'],
                                       num_players:     tournament_data['players'].length,
                                       tournament_type: TournamentType.find_or_initialize_by(name: tournament_data['type']),
                                       venue:           Venue.find_or_initialize_by(venue_attributes),
                                     })
        tournament.save!
        tournament.squadrons.destroy_all
        tournament_data['players'].each do |squadron_data|
          sync_squadron(tournament, squadron_data)
        end
      else
        raise InvalidTournament
      end
    end

    def sync_squadron(tournament, squadron_data)
      squadron = Squadron.create!({
                                    tournament:           tournament,
                                    player_name:          squadron_data['name'],
                                    xws:                  squadron_data['list'],
                                    mov:                  squadron_data['mov'],
                                    points:               squadron_data['score'],
                                    elimination_standing: squadron_data['rank']['elimination'],
                                    swiss_standing:       squadron_data['rank']['swiss'],
                                  })
      (squadron_data['list'].try(:[], 'pilots') || []).each do |ship_configuration_data|
        ship          = find_with_key(Ship, ship_configuration_data['ship'])
        pilot         = find_with_key(ship.pilots, ship_configuration_data['name'])
        configuration = ShipConfiguration.create!({
                                                    squadron: squadron,
                                                    pilot:    pilot,
                                                  })
        (ship_configuration_data['upgrades'] || []).each do |upgrade_type_key, upgrade_keys|
          upgrade_type = find_with_key(UpgradeType, upgrade_type_key)
          upgrade_keys.each do |upgrade_key|
            upgrade = find_with_key(upgrade_type.upgrades, upgrade_key)
            configuration.upgrades << upgrade
            upgrade.save!
          end
        end
      end
    end

    def find_with_key(relation, key)
      model = relation.find_by(xws: key)
      return model if model.present?
      puts "-> looking again for #{relation.name} #{key} <-"
      {
        'adv'              => 'advanced',
        'ketsupnyo'        => 'ketsuonyo',
        'pivotwing'        => 'pivotwinglanding',
        'sabinewren-swx56' => 'sabinewren',
        'Deathrain'        => 'deathrain',
        'yt2400freighter'  => 'yt2400',
      }.each do |original, substitute|
        key = key.gsub(original, substitute)
      end
      model = relation.find_by(xws: key)
      if model.present?
        puts "-> found with #{key} <-"
        model
      else
        raise "=> #{relation.name} not found for #{key} <="
      end
    end

  end
end
