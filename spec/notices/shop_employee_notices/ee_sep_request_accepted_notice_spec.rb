require 'rails_helper'

RSpec.describe ShopEmployeeNotices::EeSepRequestAcceptedNotice do
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 2.month - 1.year}
  let!(:employer_profile){ create :employer_profile, aasm_state: "active"}
  let!(:person){ create :person}
  let!(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on, :aasm_state => 'active' ) }
  let!(:active_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }
  let!(:renewal_plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on + 1.year, :aasm_state => 'renewing_draft' ) }
  let!(:renewal_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: renewal_plan_year, title: "Benefits #{renewal_plan_year.start_on.year}") }
  let(:employee_role) {FactoryGirl.create(:employee_role, person: person, employer_profile: employer_profile)}
  let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id, employer_profile_id: employer_profile.id) }
  let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person)}
  let(:benefit_group_assignment)  { FactoryGirl.create(:benefit_group_assignment, benefit_group: active_benefit_group, census_employee: census_employee) }
  let!(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, benefit_group_assignment: benefit_group_assignment, household: family.active_household, effective_on: TimeKeeper.date_of_record.beginning_of_month + 2.month, plan: renewal_plan, aasm_state: 'coverage_termination_pending')}
  let(:renewal_plan) { FactoryGirl.create(:plan)}
  let(:plan) { FactoryGirl.create(:plan, :with_premium_tables, :renewal_plan_id => renewal_plan.id)}
  let(:application_event){ double("ApplicationEventKind",{
                            :name =>'EE SEP Requested Accepted',
                            :notice_template => 'notices/shop_employee_notices/ee_sep_request_accepted_notice',
                            :notice_builder => 'ShopEmployeeNotices::EeSepRequestAcceptedNotice',
                            :event_name => 'ee_sep_request_accepted_notice',
                            :mpi_indicator => 'MPI_SHOP36',
                            :title => "Special Enrollment Period Approval"})
                          }
  let(:qle_on) {Date.new(TimeKeeper.date_of_record.year, 04, 14)}
  let(:end_on) {qle_on+30.days}
  let(:title) { "had a baby"}

  let(:valid_params) {{
      :subject => application_event.title,
      :mpi_indicator => application_event.mpi_indicator,
      :event_name => application_event.event_name,
      :options => {:qle_on => qle_on.to_s, :end_on => end_on.to_s, :title => title},
      :template => application_event.notice_template
  }}

  describe "New" do
    before do
      allow(census_employee.employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employee_notice = ShopEmployeeNotices::EeSepRequestAcceptedNotice.new(census_employee, valid_params)
    end
    context "valid params" do
      it "should initialze" do
        expect{ShopEmployeeNotices::EeSepRequestAcceptedNotice.new(census_employee, valid_params)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_params.delete(key)
          expect{ShopEmployeeNotices::EeSepRequestAcceptedNotice.new(census_employee, valid_params)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    before do
      allow(census_employee.employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      @employee_notice = ShopEmployeeNotices::EeSepRequestAcceptedNotice.new(census_employee, valid_params)
    end

    it "should build notice with all necessory info" do
      @employee_notice.build
      expect(@employee_notice.notice.primary_fullname).to eq census_employee.employer_profile.staff_roles.first.full_name.titleize
      expect(@employee_notice.notice.employer_name).to eq employer_profile.organization.legal_name
    end
  end

  describe "append data" do
    let(:special_enrollment_period) {[double("SpecialEnrollmentPeriod")]}
    let(:sep1) {family.special_enrollment_periods.new}
    let(:sep2) {family.special_enrollment_periods.new}
    let(:order) {[sep1,sep2]}

    before do
      allow(census_employee.employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
      allow(census_employee.employee_role.person.primary_family).to receive_message_chain("special_enrollment_periods.order_by").and_return(order)
      @employee_notice = ShopEmployeeNotices::EeSepRequestAcceptedNotice.new(census_employee, valid_params)
      sep1.qle_on = qle_on
      sep1.end_on = end_on
      sep1.title = title
      allow(census_employee).to receive(:active_benefit_group_assignment).and_return benefit_group_assignment
      @employee_notice.append_data
      @employee_notice.build
      @employee_notice.generate_pdf_notice
    end

    it "should append data" do
      sep = census_employee.employee_role.person.primary_family.special_enrollment_periods.order_by(:"created_at".desc)[0]
      @employee_notice.append_data
      expect(@employee_notice.notice.sep.qle_on).to eq qle_on
      expect(@employee_notice.notice.sep.end_on).to eq end_on
      expect(@employee_notice.notice.sep.title).to eq title
    end

    it "should render ee_sep_request_accepted_notice" do
      expect(@employee_notice.template).to eq "notices/shop_employee_notices/ee_sep_request_accepted_notice"
    end

    it "should generate pdf" do
      @employee_notice.build
      file = @employee_notice.generate_pdf_notice
      expect(File.exist?(file.path)).to be true
    end
  end
end
