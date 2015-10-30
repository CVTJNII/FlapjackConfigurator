require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

TestCommon.setup_test do |rspec_obj|
  rspec_obj.describe 'object removal' do
    before :all do
      # Load flapjack with test entities
      fail 'Failed to create test entities' unless @test_diner.diner.create_entities(Array.new(100) { |c| { name: "testentity-#{c}", id: "testentity-#{c}" } })
      @test_config = TestCommon.load_config('obj_removal_setup')
      # Load Flapjack with the things
      FlapjackConfigurator.configure_flapjack(@test_config, @test_container.api_url, @logger, true)
    end

    # Because I don't trust anything and we're testing absence
    describe 'pretest sanity' do
      # The test sets up two contacts the same way
      %w(loaded_test removal_test).each do |contact_name|
        describe "#{contact_name} contact" do
          before :all do
            @api_contact_links = @test_diner.diner.contacts(contact_name)[0][:links]
          end

          [:entities, :media, :notification_rules].each do |thing|
            it "has #{thing}s linked to it" do
              # media is 2, notification_rules has 2, entities has 101 or so
              expect(@api_contact_links[thing].length).to be >= 2
            end
          end

          # special case...
          it 'has pagerduty linked to it' do
            expect(@test_diner.diner.pagerduty_credentials(contact_name)).not_to be_nil
          end
        end
      end
    end

    describe 'operation' do
      before :all do
        # Strip down the config
        #
        # Delete the test delete contact
        @test_config['contacts'].delete('removal_test')
        # Delete things from the loaded test
        @test_config['contacts']['loaded_test'].delete('entities')
        @test_config['contacts']['loaded_test']['notification_media'] = {}
        # Leave the default notification rule to prevent false failures from Flapjack adding a default
        @test_config['contacts']['loaded_test']['notification_rules'].delete('rule1')
        @test_config['contacts']['loaded_test']['notification_rules'].delete('rule2')
      end

      it 'returns true as changes are made' do
        expect(FlapjackConfigurator.configure_flapjack(@test_config, @test_container.api_url, @logger, true)).to eql(true)
      end

      it 'deletes the removal_test contact' do
        expect(@test_diner.diner.contacts('removal_test')).to be_nil
      end

      # Wording is getting contrived...
      describe 'against the loaded_test user' do
        before :all do
          @api_contact_links = @test_diner.diner.contacts('loaded_test')[0][:links]
        end

        [:entities, :media].each do |thing|
          it "removes the #{thing}s" do
            expect(@api_contact_links[thing]).to eql([])
          end
        end

        it 'removes all but the default notification rule' do
          expect(@api_contact_links[:notification_rules]).to eql(%w(loaded_test_default))
        end

        # special case...
        it 'removes the pagerduty credentials' do
          expect(@test_diner.diner.pagerduty_credentials('loaded_test')).to eql([])
        end
      end
    end
  end
end
