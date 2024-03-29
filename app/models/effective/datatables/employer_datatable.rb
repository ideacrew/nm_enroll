
module Effective
  module Datatables
    class EmployerDatatable < Effective::MongoidDatatable
      datatable do


        bulk_actions_column do
           bulk_action 'Generate Invoice', generate_invoice_exchanges_hbx_profiles_path, data: { confirm: 'Generate Invoices?', no_turbolink: true }
           bulk_action 'Mark Binder Paid', binder_paid_exchanges_hbx_profiles_path, data: {  confirm: 'Mark Binder Paid?', no_turbolink: true }
           bulk_action 'Disable SSN Requirement', disable_ssn_requirement_exchanges_hbx_profiles_path(:can_update => 'disable'), data: { confirm: 'disable ssn requirement?', no_turbolink: true }
           bulk_action 'Enable SSN Requirement', disable_ssn_requirement_exchanges_hbx_profiles_path(:can_update => 'enable'), data: { confirm: 'enable ssn requirement?', no_turbolink: true }
        end

        table_column :legal_name, :proc => Proc.new { |row|
          @employer_profile = row.employer_profile
          (link_to row.legal_name.titleize, employers_employer_profile_path(@employer_profile, :tab=>'home')) + raw("<br>") + truncate(row.id.to_s, length: 8, omission: '' )

          }, :sortable => false, :filter => false
        #table_column :hbx_id, :label => 'HBX ID', :proc => Proc.new { |row| truncate(row.id.to_s, length: 8, omission: '' ) }, :sortable => false, :filter => false
        table_column :fein, :label => 'FEIN', :proc => Proc.new { |row| row.fein }, :sortable => false, :filter => false
        table_column :hbx_id, :label => 'HBX ID', :proc => Proc.new { |row| row.hbx_id }, :sortable => false, :filter => false
#        table_column :eligibility, :proc => Proc.new { |row| eligibility_criteria(@employer_profile) }, :filter => false
        table_column :broker, :proc => Proc.new { |row|
            @employer_profile.try(:active_broker_agency_legal_name).try(:titleize) #if row.employer_profile.broker_agency_profile.present?
          }, :filter => false
        table_column :general_agency, :proc => Proc.new { |row|
          @employer_profile.try(:active_general_agency_legal_name).try(:titleize) #if row.employer_profile.active_general_agency_legal_name.present?
        }, :filter => false
        table_column :conversion, :proc => Proc.new { |row| boolean_to_glyph(@employer_profile.is_conversion?)}, :filter => {include_blank: false, :as => :select, :collection => ['All','Yes', 'No'], :selected => 'All'}

        table_column :plan_year_state, :proc => Proc.new { |row|
          if @employer_profile.present?
            @latest_plan_year = @employer_profile.dt_display_plan_year
            @latest_plan_year.aasm_state.titleize if @latest_plan_year.present?
          end }, :filter => false
        table_column :effective_date, :proc => Proc.new { |row|
          @latest_plan_year.try(:start_on)
          }, :filter => false, :sortable => true
        table_column :invoiced?, :proc => Proc.new { |row| boolean_to_glyph(row.current_month_invoice.present?)}, :filter => false
#        table_column :participation, :proc => Proc.new { |row| @latest_plan_year.try(:employee_participation_percent)}, :filter => false
#        table_column :enrolled_waived, :label => 'Enrolled/Waived', :proc => Proc.new { |row|

#          enrolled = @latest_plan_year.try(:enrolled_summary)
#          waived = @latest_plan_year.try(:waived_summary)
#          enrolled.to_s + "/" + waived.to_s
#          }, :filter => false, :sortable => false
        table_column :xml_submitted, :label => 'XML Submitted', :proc => Proc.new {|row| format_time_display(@employer_profile.xml_transmitted_timestamp)}, :filter => false, :sortable => false
        table_column :actions, :width => '50px', :proc => Proc.new { |row|
          dropdown = [
           # Link Structure: ['Link Name', link_path(:params), 'link_type'], link_type can be 'ajax', 'static', or 'disabled'
           ['Transmit XML', transmit_group_xml_exchanges_hbx_profile_path(row.employer_profile), @employer_profile.is_transmit_xml_button_disabled? ? 'disabled' : 'static'],
           ['Generate Invoice', generate_invoice_exchanges_hbx_profiles_path(ids: [row]), generate_invoice_link_type(row)],
           [text_to_display(row.employer_profile), disable_ssn_requirement_exchanges_hbx_profiles_path(ids: [row], no_ssn_field: row.employer_profile.no_ssn), 'post_ajax'],
           ['View Username and Email', get_user_info_exchanges_hbx_profiles_path(people_id: Person.where({"employer_staff_roles.employer_profile_id" => row.employer_profile._id}).map(&:id), employers_action_id: "family_actions_#{row.id.to_s}"), pundit_allow(Family, :can_view_username_and_email?) ? 'ajax' : 'disabled'],
           ['Plan Years', exchanges_employer_applications_path(employer_id: row.employer_profile._id, employers_action_id: "family_actions_#{row.id}"), 'ajax'],
           ['Force Publish', edit_force_publish_exchanges_hbx_profiles_path(row_actions_id: "family_actions_#{row.id.to_s}"), force_publish_link_type(row, pundit_allow(HbxProfile, :can_force_publish?))]
          ]
          render partial: 'datatables/shared/dropdown', locals: {dropdowns: dropdown, row_actions_id: "family_actions_#{row.id.to_s}"}, formats: :html
        }, :filter => false, :sortable => false

      end

      def generate_invoice_link_type(row)
        (row.current_month_invoice.present? || !row.employer_profile.is_new_employer?) ? 'disabled' : 'post_ajax'
      end

      def business_policy_accepted?(draft_plan_year)
        TimeKeeper.date_of_record > draft_plan_year.due_date_for_publish && TimeKeeper.date_of_record < draft_plan_year.start_on
      end

      def force_publish_link_type(row, allow)
        draft_plan_year = row.renewing_or_draft_py
        draft_plan_year_and_allow = draft_plan_year.present? && business_policy_accepted?(draft_plan_year) && allow
        draft_plan_year_and_allow ? 'ajax' : 'hide'
      end

      def collection
        return @employer_collection if defined? @employer_collection
        employers = Organization.all_employer_profiles
        if attributes[:employers].present? && !['all'].include?(attributes[:employers])
          employers = employers.send(attributes[:employers]) if ['employer_profiles_applicants','employer_profiles_enrolling','employer_profiles_enrolled'].include?(attributes[:employers])
          employers = employers.send(attributes[:enrolling]) if attributes[:enrolling].present?
          employers = employers.send(attributes[:enrolling_initial]) if attributes[:enrolling_initial].present?
          employers = employers.send(attributes[:enrolling_renewing]) if attributes[:enrolling_renewing].present?

          employers = employers.send(attributes[:enrolled]) if attributes[:enrolled].present?

          if attributes[:upcoming_dates].present?
              if date = Date.strptime(attributes[:upcoming_dates], "%m/%d/%Y")
                employers = employers.employer_profile_plan_year_start_on(date)
              end
          end

        end


        @employer_collection = employers

      end

      def text_to_display(employer)
        employer.no_ssn ? "Enable SSN/TIN" : "Disable SSN/TIN"
      end

      def global_search?
        true
      end

      def global_search_method
        :datatable_search
      end

      def search_column(collection, table_column, search_term, sql_column)
        if table_column[:name] == 'legal_name'
          collection.datatable_search(search_term)
        elsif table_column[:name] == 'fein'
          collection.datatable_search_fein(search_term)
        elsif table_column[:name] == 'conversion'
          if search_term == "Yes"
            collection.datatable_search_employer_profile_source("conversion")
          elsif search_term == "No"
            collection.datatable_search_employer_profile_source("self_serve")
          else
            super
          end
        else
          super
        end
      end

      def nested_filter_definition

        @next_30_day = TimeKeeper.date_of_record.next_month.beginning_of_month
        @next_60_day = @next_30_day.next_month
        @next_90_day = @next_60_day.next_month

        filters = {
        enrolling_renewing:
          [
            {scope: 'employer_profiles_renewing_application_pending', label: 'Application Pending'},
            {scope: 'employer_profiles_renewing_open_enrollment', label: 'Open Enrollment'},
          ],
        enrolling_initial:
          [
            {scope: 'employer_profiles_initial_application_pending', label: 'Application Pending'},
            {scope: 'employer_profiles_initial_open_enrollment', label: 'Open Enrollment'},
            {scope: 'employer_profiles_binder_pending', label: 'Binder Pending'},
            {scope: 'employer_profiles_binder_paid', label: 'Binder Paid'},
          ],
        enrolled:
          [
            {scope:'employer_profiles_enrolled', label: 'All' },
            {scope:'employer_profiles_suspended', label: 'Suspended' },
          ],
          upcoming_dates:
            [
              {scope: @next_30_day, label: @next_30_day },
              {scope: @next_60_day, label: @next_60_day },
              {scope: @next_90_day, label: @next_90_day },
              #{scope: "employer_profile_plan_year_start_on('#{@next_60_day})'", label: @next_60_day },
              #{scope: "employer_profile_plan_year_start_on('#{@next_90_day})'",  label: @next_90_day },
            ],
        enrolling:
          [
            {scope: 'employer_profiles_enrolling', label: 'All'},
            {scope: 'employer_profiles_initial_eligible', label: 'Initial', subfilter: :enrolling_initial},
            {scope: 'employer_profiles_renewing', label: 'Renewing / Converting', subfilter: :enrolling_renewing},
            {scope: 'employer_profiles_enrolling', label: 'Upcoming Dates', subfilter: :upcoming_dates},
          ],
        employers:
         [
           {scope:'all', label: 'All'},
           {scope:'employer_profiles_applicants', label: 'Applicants'},
           {scope:'employer_profiles_enrolling', label: 'Enrolling', subfilter: :enrolling},
           {scope:'employer_profiles_enrolled', label: 'Enrolled', subfilter: :enrolled},
         ],
        top_scope: :employers
        }

      end
    end
  end
end
