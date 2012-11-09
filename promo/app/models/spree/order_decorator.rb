Spree::Order.class_eval do
  attr_accessible :coupon_code
  attr_accessor :coupon_code

  attr_accessor :promotions

  # Tells us if there if the specified promotion is already associated with the order
  # regardless of whether or not its currently eligible.  Useful because generally
  # you would only want a promotion to apply to order no more than once.
  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  unless self.method_defined?('update_adjustments_with_promotion_limiting')
    def update_adjustments_with_promotion_limiting
      update_adjustments_without_promotion_limiting
      return if adjustments.promotion.eligible.none?

      # TODO here the promotions should be recalculated in case anything changed
      # note that this method does not seem to be called when update_attributes is called
      # this would mean:
      #   1) existing promotions are updated even when Promotion.activate is never called
      #      e.g. in the case of a cart update
      #   2) if an update! is called before all the promotions are processed then we can
      #      be certain that the values in the promotion adjustments are the latest
      #      we wouldn't have to be as aggressive in deleting everything
      #   3) at this point everything that has been marked as ineligible
    
      most_valuable_adjustment = adjustments.promotion.eligible.max{|a,b| a.amount.abs <=> b.amount.abs}
      current_adjustments = (adjustments.promotion.eligible - [most_valuable_adjustment])
      current_adjustments.each do |adjustment|
        adjustment.update_attribute_without_callbacks(:eligible, false)
      end
    end
    alias_method_chain :update_adjustments, :promotion_limiting
  end

  def promo_total
    adjustments.eligible.promotion.map(&:amount).sum
  end
end
