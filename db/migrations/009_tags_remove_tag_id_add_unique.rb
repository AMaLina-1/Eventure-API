# frozen_string_literal: true

Sequel.migration do
  up do
    # 關閉外鍵檢查
    run 'PRAGMA foreign_keys = OFF' if App.environment != :production

    # SQLite 需要重建整個表來修改主鍵
    create_table(:tags_new) do
      primary_key :id
      String :tag, null: true, unique: true
    end

    # 複製資料（如果有的話）
    run 'INSERT INTO tags_new (tag) SELECT DISTINCT tag FROM tags WHERE tag IS NOT NULL'

    # 刪除舊表
    drop_table(:tags)

    # 重命名新表
    rename_table(:tags_new, :tags)

    # 重建關聯表
    drop_table(:activities_tags) if table_exists?(:activities_tags)
    create_table(:activities_tags) do
      foreign_key :activity_id, :activities, on_delete: :cascade
      foreign_key :tag_id, :tags, on_delete: :cascade
      primary_key %i[activity_id tag_id]
    end

    # 開啟外鍵檢查
    run 'PRAGMA foreign_keys = ON' if App.environment != :production
  end

  down do
    run 'PRAGMA foreign_keys = OFF' if App.environment != :production

    drop_table(:activities_tags)
    create_table(:tags) do
      Integer :tag_id, primary_key: true
      String :tag, null: true
    end
    create_table(:activities_tags) do
      foreign_key :activity_id, :activities, on_delete: :cascade
      foreign_key :tag_id, :tags, on_delete: :cascade
      primary_key %i[activity_id tag_id]
    end

    run 'PRAGMA foreign_keys = ON' if App.environment != :production
  end
end
