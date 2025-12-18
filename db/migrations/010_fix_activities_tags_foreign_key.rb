# frozen_string_literal: true

Sequel.migration do
  up do
    # 重建 activities_tags 表，明確指定 tag_id 參照 tags.id
    drop_table(:activities_tags) if table_exists?(:activities_tags)
    create_table(:activities_tags) do
      foreign_key :activity_id, :activities, on_delete: :cascade
      foreign_key :tag_id, :tags, key: :id, on_delete: :cascade
      primary_key %i[activity_id tag_id]
    end
  end

  down do
    drop_table(:activities_tags)
    create_table(:activities_tags) do
      foreign_key :activity_id, :activities, on_delete: :cascade
      foreign_key :tag_id, :tags, on_delete: :cascade
      primary_key %i[activity_id tag_id]
    end
  end
end
