class ShipCombosController < ApplicationController

  def index
    @view = Rankers::ShipCombosRanker.new(ranking_configuration, limit: 30)
  end

  def show
    ship_combo         = ShipCombo.find(params[:id])
    ships_ranker       = Rankers::ShipsRanker.new(ranking_configuration, ship_combo_id: params[:id])
    ship_combos_ranker = Rankers::ShipCombosRanker.new(ranking_configuration, ship_combo_id: params[:id])
    @view              = OpenStruct.new({
                                          ship_combo:        ship_combo,
                                          ship_combos:       ship_combos_ranker.ship_combos,
                                          ship_combos_ships: ship_combos_ranker.ships,
                                          squadrons:         Rankers::SquadronsRanker.new(ranking_configuration, ship_combo_id: params[:id]).squadrons,
                                          pilots:            Rankers::PilotsRanker.new(ranking_configuration, ship_combo_id: params[:id]).pilots,
                                        })
  end

  def update
    ShipCombo.find(params[:id]).update(ship_combo_attributes)
  end

  def ship_combo_attributes
    params.require(:upgrade).allow(:archetype_name)
  end

end
