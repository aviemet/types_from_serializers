require "vanilla/config/boot"
require "vanilla/config/environment"

describe "Generator" do
  let(:output_dir) { Pathname.new File.expand_path("../support/generated", __dir__) }
  let(:sample_dir) { Rails.root.join("app/frontend/types/serializers") }
  let(:serializers) {
    %w[
      Nested::AlbumSerializer
      VideoWithSongSerializer
      VideoSerializer
      SongSerializer
      SongWithVideosSerializer
      ModelSerializer
      ComposerWithSongsSerializer
      ComposerSerializer
      SnakeComposerSerializer
    ]
  }

  def file_for(dir, name, extension = ".ts")
    dir.join("#{name.chomp("Serializer").gsub("::", "/")}#{extension}")
  end

  def app_file_for(name, extension = nil)
    file_for(sample_dir, name, extension)
  end

  def output_file_for(name, extension = nil)
    file_for(output_dir, name, extension)
  end

  def expect_generator
    expect(TypesFromSerializers)
  end

  def generate_serializers
    receive(:serializer_interface_content).and_call_original
  end

  original_config = TypesFromSerializers::Config.new TypesFromSerializers.config.clone.to_h.transform_values(&:clone)

  before do
    TypesFromSerializers.instance_variable_set(:@config, original_config)

    # Change the configuration to use a different directory.
    TypesFromSerializers.config do |config|
      config.output_dir = output_dir
    end

    output_dir.rmtree if output_dir.exist?
  end

  # NOTE: We do a manual snapshot test for now, more tests coming in the future.
  describe "File output" do
    it "generates the files as expected" do
      expect_generator.to generate_serializers.exactly(serializers.size).times
      TypesFromSerializers.generate
    end

    context "with default config" do
      it "does not generate routes that don't have `export: true`." do
        expect(output_file_for("BaseSerializer").exist?).to be false
      end

      it "generates one file per serializer." do
        serializers.each do |name|
          output_file = output_file_for(name)
          expect(output_file.read).to match_snapshot("interfaces_#{name}") # UPDATE_SNAPSHOTS="1" bin/rspec
        end
      end

      it "generates a file that exports all interfaces." do
        index_file = output_dir.join("index.ts")
        expect(index_file.exist?).to be true
        expect(index_file.read).to match_snapshot("interfaces_index") # UPDATE_SNAPSHOTS="1" bin/rspec
      end
    end

    context "with config.namespace" do
      TypesFromSerializers.config do |config|
        config.namespace = "Schema"
      end

      it "does not generate routes that don't have `export: true`." do
        expect(output_file_for("BaseSerializer", ".d.ts").exist?).to be false
      end

      it "generates one file per serializer." do
        serializers.each do |name|
          output_file = output_file_for(name)
          expect(output_file.read).to match_snapshot("namespace_interfaces_#{name}") # UPDATE_SNAPSHOTS="1" bin/rspec
        end
      end

      it "doesn't generate an index file" do
        index_file = output_dir.join("index.ts")
        expect(index_file.exist?).to be false
      end
    end

    it "does not render if generating again." do
      TypesFromSerializers.generate
    end
  end

  it "has a rake task available" do
    Rails.application.load_tasks
    expect_generator.to generate_serializers.exactly(serializers.size).times
    expect { Rake::Task["types_from_serializers:generate"].invoke }.not_to raise_error
  end

  describe "types mapping" do
    it "maps citext type from SQL to string type in TypeScript" do
      db_type = :citext

      ts_type = TypesFromSerializers.config.sql_to_typescript_type_mapping[db_type]

      expect(ts_type).to eq(:string)
    end
  end
end
