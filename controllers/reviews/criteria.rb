# Buhos
# https://github.com/clbustos/buhos
# Copyright (c) 2016-2018, Claudio Bustos Navarrete
# All rights reserved.
# Licensed BSD 3-Clause License
# See LICENSE file for more information


# @!group Inclusion and exclusion criteria


post '/review/:rs_id/criteria/:action' do |rs_id,action|
  halt_unless_auth('review_edit')
  @review=SystematicReview[rs_id]
  raise Buhos::NoReviewIdError, rs_id if !@review
  $db.transaction do
    case action
      when "add"
        criterion=Criterion.get_criterion(params['text'].chomp)
        SrCriterion.sr_criterion_add(@review,criterion, params['cr_type'])
      when "remove"
        criterion=Criterion[params['cr_id']]
        SrCriterion.sr_criterion_remove(@review,criterion)
      else
      raise "Unknown action:#{action}"
    end

  end
  partial("systematic_reviews/criteria", :locals=>{sr:@review, ajax:true, type:params['cr_type']})
end

post '/review/criteria/cd' do


  cd = CanonicalDocument[params['cd_id']]
  sr = SystematicReview[params['sr_id']]
  user = User[params['user_id']]
  criterion=Criterion[params['criterion_id']]
  checked = params['checked'].to_i==1

  raise Buhos::NoReviewIdError, params['sr_id'] if !sr
  raise Buhos::NoCdIdError , params['cd_id'] if !cd
  raise Buhos::NoUserIdError, params['user_id'] if !user
  raise Buhos::NoCriterionIdError, params['criterion_id'] if !criterion

  h_crit={criterion_id:criterion[:id], canonical_document_id: cd[:id], user_id:user[:id], systematic_review_id: sr[:id]}
  cd_criteria=CdCriterion[h_crit]
  if !cd_criteria
    CdCriterion.insert(h_crit.merge({selected:checked}))
  else
    cd_criteria.update(selected:checked)
  end
  200


end

# @!endgroup