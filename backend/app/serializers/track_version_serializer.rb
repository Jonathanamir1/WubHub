class TrackVersionSerializer < ActiveModel::Serializer
  attributes :id, :title, :waveform_data, :created_at, :updated_at, :user_id, :project_id, :metadata, :username

  def username
    object.user.username
  end
end