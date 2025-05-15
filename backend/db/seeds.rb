
# Clear existing data
puts "Clearing existing data..."
Workspace.destroy_all
User.destroy_all
Project.destroy_all
TrackVersion.destroy_all

# Create users
puts "Creating users..."
admin = User.create!(
  email: "admin@wubhub.com",
  username: "admin",
  name: "Admin User",
  bio: "System administrator",
  password: "password",
  password_confirmation: "password"
)

producer = User.create!(
  email: "producer@wubhub.com",
  username: "producer1",
  name: "Pro Producer",
  bio: "Music producer specializing in electronic music",
  password: "password",
  password_confirmation: "password"
)

vocalist = User.create!(
  email: "vocalist@wubhub.com",
  username: "vocalist",
  name: "Vocal Artist",
  bio: "Professional vocalist and songwriter",
  password: "password",
  password_confirmation: "password"
)

# Create workspaces
puts "Creating workspaces..."
production_workspace = Workspace.create!(
  name: "Music Production",
  description: "Main workspace for production projects",
  workspace_type: "production",
  visibility: "private",
  user: producer
)

songwriting_workspace = Workspace.create!(
  name: "Songwriting",
  description: "Collaborative songwriting space",
  workspace_type: "songwriting",
  visibility: "private",
  user: vocalist
)

# Create projects
puts "Creating projects..."
summer_ep = Project.create!(
  title: "Summer EP",
  description: "Four-track summer vibes EP",
  visibility: "private",
  workspace: production_workspace,
  user: producer
)

client_mix = Project.create!(
  title: "Client Mix - Jane Doe",
  description: "Mixing project for Jane's album",
  visibility: "private",
  workspace: production_workspace,
  user: producer
)

song_ideas = Project.create!(
  title: "New Song Ideas",
  description: "Collection of demos and song ideas",
  visibility: "private",
  workspace: songwriting_workspace,
  user: vocalist
)

# Create track versions
puts "Creating track versions..."
# For Summer EP
TrackVersion.create!(
  title: "Initial Demo",
  project: summer_ep,
  user: producer,
  metadata: { bpm: 128, key: "A min" }
)

TrackVersion.create!(
  title: "Added Vocals",
  project: summer_ep,
  user: vocalist,
  metadata: { bpm: 128, key: "A min" }
)

TrackVersion.create!(
  title: "Mix v1",
  project: summer_ep,
  user: producer,
  metadata: { bpm: 128, key: "A min" }
)

# For Client Mix
TrackVersion.create!(
  title: "Raw Stems",
  project: client_mix,
  user: producer,
  metadata: { bpm: 95, key: "D maj" }
)

TrackVersion.create!(
  title: "Mix Draft",
  project: client_mix,
  user: producer,
  metadata: { bpm: 95, key: "D maj" }
)

# For Song Ideas
TrackVersion.create!(
  title: "Voice Memo - Verse Idea",
  project: song_ideas,
  user: vocalist,
  metadata: { key: "G min" }
)

TrackVersion.create!(
  title: "Guitar Chord Progression",
  project: song_ideas,
  user: vocalist,
  metadata: { key: "G min" }
)

puts "Seed data created successfully!"