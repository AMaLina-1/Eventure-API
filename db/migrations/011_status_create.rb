# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:status) do
      String :status_name, primary_key: true
      String :status, null: true
    end
  end
end
