require Rails.root.join('lib', 'tasks', 'hbx_import', 'qhp', 'parsers', 'plan_attributes_parser')
require Rails.root.join('lib', 'tasks', 'hbx_import', 'qhp', 'parsers', 'cost_share_variance_parser')

module Parser
  class PlanParser
    include HappyMapper

    tag 'plans'

    has_one :plan_attributes, Parser::PlanAttributesParser, tag: 'planAttributes'
    has_one :cost_share_variance_attributes, Parser::CostShareVarianceParser, tag: 'costShareVariance', deep: true

    def to_hash
      {
        plan_attributes: plan_attributes.to_hash,
        cost_share_variance_attributes: cost_share_variance_attributes.to_hash
      }
    end
  end
end