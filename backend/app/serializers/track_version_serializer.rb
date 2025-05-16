class TrackVersionSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :waveform_data, :created_at, :updated_at, :user_id, :project_id, :metadata, :username

  has_many :track_contents

  def username
    object.user.username
  end
end