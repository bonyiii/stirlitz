Sequel.migration do
  change do
    add_column :codeship_builds, :project_uuid, String
    drop_column :codeship_builds, :badge_url
  end
end
