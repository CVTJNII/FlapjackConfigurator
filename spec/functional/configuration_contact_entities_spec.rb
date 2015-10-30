require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

# Class representing a set of identities
# Used to build sets of entities for testing
class TestEntityIDs
  attr_reader :idlist

  def initialize(idlist)
    @idlist = idlist
  end

  def -(other)
    return TestEntityIDs.new(@idlist - other.idlist)
  end

  def id_name(id)
    fail 'Bad ID' unless id
    return "testentity-#{id}"
  end

  def entity_create_list
    # Returns a list in the format needed by Flapjack::Diner.create_entities
    return @idlist.map { |id| { name: id_name(id), id: id_name(id) } }
  end

  def names
    return @idlist.map { |id| id_name(id) }
  end
end

TestCommon.setup_test do |rspec_obj|
  rspec_obj.describe 'contact entities' do
    before :all do
      # Load flapjack with test entities
      @remaining_entities = TestEntityIDs.new(Array.new(100) { |c| c })
      fail 'Failed to create test entities' unless @test_diner.diner.create_entities(@remaining_entities.entity_create_list)
    end

    it 'Returns true as the config is updated' do
      expect(FlapjackConfigurator.configure_flapjack(TestCommon.load_config('entities'), @test_container.api_url, @logger, true)).to eq(true)
    end

    describe 'matchers' do
      before :all do
        @contact_entities = @test_diner.diner.contacts('search_test')[0][:links][:entities]

        # Generate the lists for the tests here to only define the IDs once.
        # popping magic doesn't work due to rspec test independence.
        @whitelist_exact_entities = TestEntityIDs.new([1, 3, 31, 71])

        @blacklist_exact_entities = TestEntityIDs.new([21, 23, 61, 63])
        # Blacklist regex ranges minus the two whitelist pins
        @blacklist_regex_entities = TestEntityIDs.new((Array.new(10) { |c| c + 30 } + Array.new(10) { |c| c + 70 }) - [31, 71])

        @whitelist_regex_entities = TestEntityIDs.new(Array.new(30) { |c| c + 20 } + Array.new(30) { |c| c + 60 })
        @whitelist_regex_entities -= @blacklist_exact_entities
        @whitelist_regex_entities -= @blacklist_regex_entities

        @remaining_entities -= @whitelist_exact_entities
        @remaining_entities -= @whitelist_regex_entities
      end

      describe 'entities/exact' do
        it 'whitelists specified entities' do
          @whitelist_exact_entities.names.each do |ename|
            expect(@contact_entities).to include(ename)
          end
        end
      end

      describe 'entities_blacklist/exact' do
        it 'blacklists specified regexes' do
          @blacklist_exact_entities.names.each do |ename|
            expect(@contact_entities).not_to include(ename)
          end
        end
      end

      describe 'entities_blacklist/regex' do
        it 'blacklists specified regexes' do
          @blacklist_regex_entities.names.each do |ename|
            expect(@contact_entities).not_to include(ename)
          end
        end
      end

      describe 'entities/regex' do
        it 'whitelists specified regexes minus blacklists' do
          @whitelist_regex_entities.names.each do |ename|
            expect(@contact_entities).to include(ename)
          end
        end
      end

      describe 'non-specified entities' do
        it 'are not present' do
          @remaining_entities.names.each do |ename|
            expect(@contact_entities).not_to include(ename)
          end
        end
      end

      describe 'entities/default' do
        it 'matches anything orphaned' do
          expect(@test_diner.diner.contacts('default_test')[0][:links][:entities].sort).to eq(@remaining_entities.names.sort)
        end

        # Redundant, as the above will catch this, but I like having the explicit test.
        it "doesn't match the magic ALL entitiy" do
          expect(@test_diner.diner.contacts('default_test')[0][:links][:entities]).not_to include('ALL')
        end
      end
    end
  end
end
