require 'rails_helper'

RSpec.describe Employers::BrokerAgencyController do

  before(:all) do
    @employer_profile = FactoryGirl.create(:employer_profile)

    @broker_role =  FactoryGirl.create(:broker_role, aasm_state: 'active')
    @org1 = FactoryGirl.create(:organization, legal_name: "Singhal")
    @org1.broker_agency_profile.update_attributes(primary_broker_role: @broker_role)
    @broker_role.update_attributes(broker_agency_profile_id: @org1.broker_agency_profile.id)

    @broker_role2 = FactoryGirl.create(:broker_role, aasm_state: 'active')
    @org2 = FactoryGirl.create(:organization, legal_name: "Kaiser")
    @org2.broker_agency_profile.update_attributes(primary_broker_role: @broker_role2)
    @broker_role2.update_attributes(broker_agency_profile_id: @org2.broker_agency_profile.id)

    @user = FactoryGirl.create(:user)
  end

  describe ".index" do

    context 'with out search string' do
      before(:each) do
        sign_in(@user)
        xhr :get, :index, employer_profile_id: @employer_profile.id, format: :js
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render the new template" do
        expect(response).to render_template("index")
      end

      it "should assign variables" do
        expect(assigns(:broker_agency_profiles).count).to eq 2
        expect(assigns(:broker_agency_profiles)).to include(@org1.broker_agency_profile)
      end
    end

    context 'with search string' do
      before :each do
        sign_in(@user)
        xhr :get, :index, employer_profile_id: @employer_profile.id, q: @org2.broker_agency_profile.legal_name, format: :js
      end

      it 'should return matching agency' do
        expect(assigns(:broker_agency_profiles)).to eq([@org2.broker_agency_profile])
      end
    end
  end

  describe ".create" do

    context 'with out search string' do
      before(:each) do
        sign_in(@user)
        post :create, employer_profile_id: @employer_profile.id, broker_role_id: @broker_role2.id, broker_agency_id: @org2.broker_agency_profile.id
      end

      it "should be a success" do
        expect(flash[:notice]).to eq("Successfully associated broker with your account.")
        expect(response).to redirect_to(employers_employer_profile_path(@employer_profile))
      end
    end
  end

  describe ".active_broker" do

    context 'with out search string' do
      before(:each) do
        sign_in(@user)
        xhr :get, :active_broker, employer_profile_id: @employer_profile.id, format: :js
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render the new template" do
        expect(response).to render_template("active_broker")
      end

      it "should assign employer broker accounts" do
        expect(assigns(:broker_agency_accounts)[0].broker_agency_profile).to eq(@org2.broker_agency_profile)
      end
    end
  end

  describe ".terminate" do
    
    context 'with out search string' do
      before(:each) do
        sign_in(@user)
        get :terminate, employer_profile_id: @employer_profile.id, broker_agency_id: @org2.broker_agency_profile.id
      end

      it "should be a success" do
        expect(flash[:notice]).to eq("Broker terminated successfully.")
        expect(response).to redirect_to(employers_employer_profile_path(@employer_profile))
        expect(@employer_profile.broker_agency_accounts).to eq([])
      end
    end
  end
end