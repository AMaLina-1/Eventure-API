# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:activities) do
      set_column_type :serno, String, size: 255
    end
  end
end
