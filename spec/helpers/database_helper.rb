# frozen_string_literal: true

# Helper to clean database during test runs
module DatabaseHelper
  def self.wipe_database
    db = Eventure::App.db
    db.run('PRAGMA foreign_keys = OFF')

    destroy_all_tables

    db.run('PRAGMA foreign_keys = ON')
  end

  def self.destroy_all_tables
    [
      Eventure::Database::ActivityOrm,
      Eventure::Database::TagOrm,
      Eventure::Database::RelatedataOrm
    ].each do |orm|
      # orm.map(&:destroy)
      orm.all.each(&:destroy)  # 先拿到所有實例，再逐個 destroy
    end
  end
end
