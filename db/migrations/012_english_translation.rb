# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:activities) do
      add_column :name_en, String, null: true
      add_column :detail_en, :text, null: true
      add_column :location_en, String, null: true
      add_column :organizer_en, String, null: true
    end

    alter_table(:tags) do
      add_column :tag_en, String, null: true
    end
  end
end
