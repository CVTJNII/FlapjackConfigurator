require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

TestCommon.setup_config_test('notification_media') do |rspec_obj, test_config|
  # Table defining which media attributes should be used for each test contact
  test_attr_table = {
    nmt_baseline_inheritence:
      { pagerduty: { subdomain: :baseline, token: :baseline, service_key: :baseline },
        email:     { interval: :baseline, rollup_threshold: :baseline, address: :baseline },
        jabber:    { interval: :baseline, rollup_threshold: :baseline, address: :baseline } },
    nmt_default_partial_inheritance:
      { pagerduty: { subdomain: :defaults, token: :baseline, service_key: :baseline },
        email:     { interval: :defaults, rollup_threshold: :baseline, address: :defaults },
        jabber:    { interval: :defaults, rollup_threshold: :baseline, address: :defaults } },
    nmt_default_full_inheritance:
      { pagerduty: { subdomain: :defaults, token: :defaults, service_key: :defaults },
        email:     { interval: :defaults, rollup_threshold: :defaults, address: :defaults },
        jabber:    { interval: :defaults, rollup_threshold: :defaults, address: :defaults } },
    nmt_partial_contacts:
      { pagerduty: { subdomain: :contact, token: :baseline, service_key: :baseline },
        email:     { interval: :baseline, rollup_threshold: :baseline, address: :contact },
        jabber:    { interval: :baseline, rollup_threshold: :baseline, address: :contact } },
    nmt_full_contacts:
      { pagerduty: { subdomain: :contact, token: :contact, service_key: :contact },
        email:     { interval: :contact, rollup_threshold: :contact, address: :contact },
        jabber:    { interval: :contact, rollup_threshold: :contact, address: :contact } },
    nmt_real_world:
      { pagerduty: { subdomain: :contact, token: :baseline, service_key: :baseline },
        email:     { interval: :defaults, rollup_threshold: :defaults, address: :contact },
        jabber:    { interval: :defaults, rollup_threshold: :defaults, address: :contact } }
  }

  test_attr_table.each do |test_contact, contact_attr_table|
    rspec_obj.describe "#{test_contact} notification_media" do
      it 'should only have media from the config' do
        contact_rules = @test_diner.diner.contacts(test_contact)[0][:links][:media]
        expect(contact_rules - contact_attr_table.keys.map { |media| "#{test_contact}_#{media}" }).to eq([])
      end

      contact_attr_table.each do |media, media_attr_table|
        describe "#{media} media" do
          before :all do
            # Pagerduty is handled as a special case by (bolted onto) the API
            @api_media = case media
                         when :pagerduty
                           @test_diner.diner.pagerduty_credentials(test_contact)[0]
                         else
                           @test_diner.diner.media("#{test_contact}_#{media}")[0]
                         end
          end

          it 'should be associated to the contact' do
            expect(@api_media[:links][:contacts][0]).to eql(test_contact.to_s)
          end

          media_attr_table.each do |media_attr, attr_source|
            test_value = case attr_source
                         when :baseline
                           test_config['baseline_options']['notification_media'][media.to_s][media_attr.to_s]
                         when :defaults
                           test_config['contacts'][test_contact.to_s]['notification_media']['defaults'][media_attr.to_s]
                         when :contact
                           test_config['contacts'][test_contact.to_s]['notification_media'][media.to_s][media_attr.to_s]
                         else
                           fail "Unknown attribute source #{attr_source}"
                         end
            it "should use the #{attr_source} attribute for #{media_attr}" do
              expect(@api_media[media_attr]).to eql(test_value)
            end
          end
        end
      end
    end
  end
end
