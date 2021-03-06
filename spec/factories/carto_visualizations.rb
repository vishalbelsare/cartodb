require_relative '../support/factories/tables'

module Carto
  module Factories
    module Visualizations
      include CartoDB::Factories

      def full_visualization_table(carto_user, map)
        carto_user = Carto::User.find(carto_user.id) unless carto_user.is_a? Carto::User
        Carto::UserTable.find(create_table(
          name: unique_name('fvt_table'),
          user_id: carto_user.id,
          map_id: map&.id
        ).id)
      end

      def create_full_builder_vis(carto_user, visualization_attributes: {})
        create_full_visualization(carto_user, visualization_attributes: visualization_attributes.merge(version: 3))
      end

      # "Full visualization": with map, table... Including actual user table.
      # Table is bound to visualization, and to data_layer if it's not passed.
      def create_full_visualization(carto_user, params = {})
        carto_user = carto_user.carto_user
        canonical_map = params[:canonical_map] || create(:carto_map_with_layers, user_id: carto_user.id)
        map = params[:map] || create(:carto_map_with_layers, user_id: carto_user.id)
        table = params[:table] || full_visualization_table(carto_user, canonical_map)
        table_visualization = table.visualization || create_table_visualization(carto_user, table)
        visualization_attributes = { user: carto_user, map: map }
        visualization_attributes.merge!(params[:visualization_attributes]) if params[:visualization_attributes]
        visualization = create(:carto_visualization, visualization_attributes)

        build_data_layer(visualization, table) unless params[:data_layer]

        visualization.update_column(:active_layer_id, visualization.layers.first.id)

        create(:carto_zoom_overlay, visualization: visualization)
        create(:carto_search_overlay, visualization: visualization)

        # Need to mock the nonexistant table because factories use Carto::* models
        CartoDB::Visualization::Member.any_instance.stubs(:propagate_name_to).returns(true)
        CartoDB::Visualization::Member.any_instance.stubs(:propagate_privacy_to).returns(true)

        [map, table, table_visualization, visualization.reload]
      end

      def build_data_layer(visualization, table)
        data_layer = visualization.map.data_layers.first
        data_layer.options[:table_name] = table.name
        data_layer.options[:query] = "select * from #{table.name}"
        data_layer.options[:sql_wrap] = 'select * from (<%= sql %>) __wrap'
        data_layer.save
      end

      def create_table_visualization(carto_user, table)
        create(
          :carto_visualization, user: carto_user, type: 'table', name: table.name, map_id: table.map_id)
      end

      # Helper method for `create_full_visualization` results cleanup
      def destroy_full_visualization(map, table, table_visualization, visualization)
        table_visualization.destroy if table_visualization && Carto::Visualization.exists?(table_visualization.id)
        table.service.destroy if table && table.service && Carto::UserTable.exists?(table.id)
        table.destroy if table && Carto::UserTable.exists?(table.id)
        visualization.destroy if visualization && Carto::Visualization.exists?(visualization.id)
        map.destroy if map && Carto::Map.exists?(map.id)
      end

      def destroy_visualization(visualization_id)
        member = CartoDB::Visualization::Member.new(id: visualization_id).fetch
        member.delete
      end
    end
  end
end
