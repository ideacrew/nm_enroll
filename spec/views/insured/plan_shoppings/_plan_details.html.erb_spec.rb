require 'rails_helper'

RSpec.describe "insured/plan_shoppings/_plan_details.html.erb", :dbclean => :after_each do
  before :each do
    allow_any_instance_of(FinancialAssistance::Application).to receive(:set_benchmark_plan_id)
    sign_in(user)
    allow(Caches::MongoidCache).to receive(:lookup).with(CarrierProfile, anything).and_return(carrier_profile)
    assign(:person, person)
    assign(:plan_hsa_status, plan_hsa_status)
    assign(:hbx_enrollment, hbx_enrollment)
    assign(:enrolled_hbx_enrollment_plan_ids, [plan.id])
  end

  let(:carrier_profile) { instance_double("CarrierProfile", id: "carrier profile id", legal_name: "legal_name") }
  let(:user) { FactoryGirl.create(:user, person: person) }
  let(:person) { FactoryGirl.create(:person) }
  let(:family) { FactoryGirl.create(:family, :with_primary_family_member_and_dependent, person: person) }
  let(:application) { FactoryGirl.create(:application, family: family) }

  let(:plan) do
    double(plan_type: "ppo",
      metal_level: "bronze",
      is_standard_plan: true,
      nationwide: "true",
      total_employee_cost: 100,
      deductible: 500,
      family_deductible: "500 per person | $1000 per group",
      name: "My Plan",
      id: "991283912392",
      carrier_profile: nil,
      carrier_profile_id: carrier_profile.id,
      active_year: TimeKeeper.date_of_record.year,
      total_premium: 300,
      total_employer_contribution: 200,
      ehb: 0.9881,
      can_use_aptc?: true,
      :hios_id => "89789DC0010006-01",
      coverage_kind: "health",
      dental_level: "high",
      sbc_document: Document.new({title: 'sbc_file_name', subject: "SBC",
                                    :identifier=>'urn:openhbx:terms:v1:file_storage:s3:bucket:dchbx-sbc#7816ce0f-a138-42d5-89c5-25c5a3408b82'})
    )
  end

  let(:plan_hsa_status) { Hash.new }
  let(:hbx_enrollment_member1) { double("HbxEnrollmentMember", applicant_id: family.family_members[0].id) }
  let(:hbx_enrollment_member2) { double("HbxEnrollmentMember", applicant_id: family.family_members[1].id) }
  let(:hbx_enrollment_members) { [hbx_enrollment_member1, hbx_enrollment_member2]}
  let(:hbx_enrollment) do
    instance_double(
      "HbxEnrollment", id: "hbx enrollment id",
      hbx_enrollment_members: hbx_enrollment_members,
      plan: plan
    )
  end
  let(:household) { family.households.first }

  before :each do
    assign(:carrier_names_map, {})
    allow(plan).to receive(:total_employee_cost).and_return 100
    allow(plan).to receive(:is_csr?).and_return false
    application.update_attributes!(family: family)
    tax_household = FactoryGirl.create(:tax_household, household: family.active_household)
    tax_household.tax_household_members << TaxHouseholdMember.new(applicant_id: family.primary_applicant.id, is_ia_eligible: true)
    FactoryGirl.create(:eligibility_determination, tax_household: tax_household)
    tax_household.save!
    assign(:tax_household, tax_household)
  end

  context "deductible" do
    before :each do
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should display family deductible when hbx_enrollment_members count > 1" do
      expect(rendered).to include("#{plan.family_deductible.split("|").last.squish}")
    end

    it "should display individual deductible when hbx_enrollment_members count  <= 1" do
      expect(rendered).to include("#{plan.deductible}")
    end
  end

  context "without aptc" do
    before :each do
      assign(:carrier_names_map, {})
      assign(:person, person)
      allow(plan).to receive(:total_employee_cost).and_return 100
      allow(plan).to receive(:is_csr?).and_return false
      family = person.primary_family
      active_household = family.households.first
      application.update_attributes!(family: family)
      tax_household = FactoryGirl.create(:tax_household, household: household )
      eligibility_determination = FactoryGirl.create(:eligibility_determination, tax_household: tax_household)
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should display the main menu" do
      expect(rendered).not_to have_selector('a', text: /Waive/)
    end

    it "should display plan details" do
      expect(rendered).to match(/#{plan.name}/)
      expect(rendered).to match(/#{plan.carrier_profile}/)
      expect(rendered).to match(/#{plan.active_year}/)
      expect(rendered).to match(/#{plan.is_standard_plan}/)
      expect(rendered).to match(/#{plan.nationwide}/)
      expect(rendered).to match(/#{plan.total_employee_cost}/)
      expect(rendered).to match(/#{plan.plan_type}/)
      expect(rendered).to match(/#{plan.metal_level}/)
      expect(rendered).to match(/#{plan.hios_id}/)
      expect(rendered).to match(/#{plan.ehb}/)
      expect(rendered).to match(/#{plan.can_use_aptc?}/)
    end

    it "should match css selector for standard plan" do
      expect(rendered).to have_css("i.fa-bookmark", text: /standard plan/i)
      expect(rendered).to have_css("h5.bg-title", text: /your current #{plan.active_year} plan/i)
    end

    it "should display the premium" do
      expect(rendered).to have_selector('h2.plan-premium', text: "100")
    end

    it "presents a download sbc link with filename and extension" do
      file_param = "filename=MyPlan.pdf"
      expect(rendered).to have_selector('a', text:'Summary of Benefits and Coverage')
      expect(rendered).to match(/#{file_param}/)
    end

    it "should have the see details selector" do
      expect(rendered).to have_selector('a', text: /See Details/)
    end

    it "should have title text for standard plan " do
      expect(rendered).to match /Each health insurance company offers a standard plan at each metal level. Benefits and cost-sharing are the same among standard plans of the same metal level, but monthly premiums and provider network options may be different. This makes it easier for consumers to compare plans at the same metal level and choose what’s best for them./i
    end
  end

  context "with aptc" do
    before :each do
      allow(plan).to receive(:is_csr?).and_return true
      allow(view).to receive(:current_cost).and_return(52)
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should display the premium" do
      expect(rendered).to have_selector('h2.plan-premium', text: "$52.00")
    end

    it "should display plan details" do
      expect(rendered).to match(/#{plan.name}/)
      expect(rendered).to match(/#{plan.carrier_profile}/)
      expect(rendered).to match(/#{plan.active_year}/)
      expect(rendered).to match(/#{plan.deductible}/)
      expect(rendered).to match(/#{plan.is_standard_plan}/)
      expect(rendered).to match(/#{plan.nationwide}/)
      expect(rendered).to match(/#{plan.total_employee_cost}/)
      expect(rendered).to match(/#{plan.plan_type}/)
      expect(rendered).to match(/#{plan.metal_level}/)
      expect(rendered).to match(/#{plan.hios_id}/)
      expect(rendered).to match(/#{plan.can_use_aptc?}/)
    end

    it "should match css selector for standard plan" do
      expect(rendered).to have_css("i.fa-bookmark", text: /standard plan/i)
      expect(rendered).to have_css("h5.bg-title", text: /your current #{plan.active_year} plan/i)
    end

    it "should match fa-check-square for csr" do
      expect(rendered).to have_css("i.fa-check-square-o")
    end
  end

  context "with dental coverage_kind" do
    before :each do
      allow(plan).to receive(:coverage_kind).and_return('dental')
      allow(plan).to receive(:metal_level).and_return('dental')
      family = person.primary_family
      application.update_attributes!(family: family)
      tax_household = FactoryGirl.create(:tax_household, household: household )
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should have link to pdf with plan summary text" do
      expect(rendered).to have_selector('a', text:'Plan Summary')
      expect(rendered).to match "High"
    end
  end

context "with tax household and eligibility determination of csr_94" do
  before :each do
      allow(view).to receive(:params).and_return :market_kind => 'individual'
      view.instance_variable_set(:@eligibility_kind, "csr_94")
      assign(:carrier_names_map, {})
      allow(plan).to receive(:total_employee_cost).and_return 100
      allow(plan).to receive(:is_csr?).and_return false
      family = person.primary_family
      application.update_attributes!(family: family)
      tax_household = FactoryGirl.create(:tax_household, household: family.households.first , application_id: application.id)
      eligibility_determination = FactoryGirl.create(:eligibility_determination, tax_household: tax_household, source: "Curam" )
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should have hidden modal for csr elibility reminder" do
      expect(rendered).to have_css("#csrEligibleReminder-#{plan.id}", :visible => false)
    end
  end

  context "with tax household and eligibility determination of csr_94 plan shopping in 'shop' market" do
    before :each do
      allow(view).to receive(:params).and_return :market_kind => 'shop'
      family = person.primary_family
      active_household = family.households.first
      application.update_attributes!(family: family)
      tax_household = FactoryGirl.create(:tax_household, household: household )
      eligibility_determination = FactoryGirl.create(:eligibility_determination, tax_household: tax_household)
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should not have csr elibility modal in shop market" do
      expect(rendered).to_not have_css("#csrEligibleReminder-#{plan.id}")
    end
  end

  context "with tax household and eligibility determination of csr_100" do
    before :each do
      assign(:carrier_names_map, {})
      allow(plan).to receive(:total_employee_cost).and_return 100
      allow(plan).to receive(:is_csr?).and_return false
      family = person.primary_family
      active_household = family.households.first
      application.update_attributes!(family: family)
      tax_household = FactoryGirl.create(:tax_household, household: household )
      eligibility_determination = FactoryGirl.create(:eligibility_determination, tax_household: tax_household, csr_eligibility_kind: "csr_100", source: "Curam" )
      render "insured/plan_shoppings/plan_details", plan: plan
    end

    it "should not have hidden modal for csr elibility reminder" do
      expect(rendered).to_not have_css("#csrEligibleReminder-#{plan.id}")
    end
  end
end
