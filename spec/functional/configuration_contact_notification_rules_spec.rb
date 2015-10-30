require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

TestCommon.setup_config_test('notification_rules') do |rspec_obj, test_config|
  # Table defining which media attributes should be used for each test contact
  test_attr_table = {
    nrt_baseline_inheritence:
      { rules_1: { warning_media: :baseline, critical_media: :baseline },
        rules_2: { warning_media: :baseline, critical_media: :baseline } },
    nrt_default_partial_inheritance:
      { rules_1: { unknown_media: :defaults, warning_media: :defaults, critical_media: :baseline },
        rules_2: { unknown_media: :defaults, warning_media: :defaults, critical_media: :baseline } },
    nrt_default_full_inheritance:
      { rules_1: { unknown_media: :defaults, warning_media: :defaults, critical_media: :defaults },
        rules_2: { unknown_media: :defaults, warning_media: :defaults, critical_media: :defaults } },
    nrt_partial_contacts:
      { rules_1: { unknown_media: :defaults, warning_media: :contact, critical_media: :contact },
        rules_2: { unknown_media: :defaults, warning_media: :defaults, critical_media: :baseline } },
    nrt_full_contacts:
      { rules_1: { unknown_media: :contact, warning_media: :contact, critical_media: :contact },
        rules_2: { unknown_media: :contact, warning_media: :contact, critical_media: :contact } }
  }

  test_attr_table.each do |test_contact, contact_attr_table|
    rspec_obj.describe "#{test_contact} notification_rules" do
      it 'should only have rules from the config' do
        contact_rules = @test_diner.diner.contacts(test_contact)[0][:links][:notification_rules]
        expect(contact_rules - contact_attr_table.keys.map { |rule| "#{test_contact}_#{rule}" }).to eq([])
      end

      contact_attr_table.each do |rule, rules_attr_table|
        describe "#{rule} rules" do
          before :all do
            @api_rules = @test_diner.diner.notification_rules("#{test_contact}_#{rule}")[0]
          end

          it 'should be associated to the contact' do
            expect(@api_rules[:links][:contacts][0]).to eql(test_contact.to_s)
          end

          rules_attr_table.each do |rules_attr, attr_source|
            test_value = case attr_source
                         when :baseline
                           test_config['baseline_options']['notification_rules'][rule.to_s][rules_attr.to_s]
                         when :defaults
                           test_config['contacts'][test_contact.to_s]['notification_rules']['defaults'][rules_attr.to_s]
                         when :contact
                           test_config['contacts'][test_contact.to_s]['notification_rules'][rule.to_s][rules_attr.to_s]
                         end
            it "should use the #{attr_source} attribute for #{rules_attr}" do
              expect(@api_rules[rules_attr]).to eql(test_value)
            end
          end
        end
      end
    end
  end
end
