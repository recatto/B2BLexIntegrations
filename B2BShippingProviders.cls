global class B2BShippingProviders implements sfdc_checkout.CartShippingCharges {

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {

        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();

        try {

            Id cartDeliveryGroupId = [SELECT CartDeliveryGroupId FROM CartItem WHERE CartId = :cartId][0].CartDeliveryGroupId;

            delete [SELECT Id FROM CartDeliveryGroupMethod WHERE CartDeliveryGroupId = :cartDeliveryGroupId];

            Id defaultOrderDeliveryMethodId = getDefaultOrderDeliveryMethod();

            populateCartDeliveryGroupMehodWithShippingOptions(cartDeliveryGroupId,
                                                              defaultOrderDeliveryMethodId,
                                                              cartId);

            CartDeliveryGroupMethod selectedCartDeliveryGroupMethod = [SELECT ShippingFee, DeliveryMethodId FROM CartDeliveryGroupMethod WHERE CartDeliveryGroupId = :cartDeliveryGroupId][0];

            Decimal shippingRate = selectedCartDeliveryGroupMethod.ShippingFee;
            Id orderDeliveryMethodId = selectedCartDeliveryGroupMethod.DeliveryMethodId;
            
            delete [SELECT Id FROM CartItem WHERE Type = 'Charge' and CartId = :cartId];
            
            Id shippingChargeProduct2Id = getShippingChargeProduct2Id(orderDeliveryMethodId);

            CartItem deliveryCharge = new CartItem(
                Type = 'Charge',
                Product2Id = shippingChargeProduct2Id,
                Quantity = 1.0,
                TotalPrice = shippingRate,
                ListPrice = shippingRate,
                TotalListPrice = shippingRate,
                TotalLineAmount = shippingRate,
                AdjustmentAmount = 0.0,
                CartId = cartId,
                CartDeliveryGroupId = cartDeliveryGroupId,
                Name = 'Shipping Cost'
            );
            insert(deliveryCharge);
            addOrderDeliveryMethodToCartDeliveryGroup(orderDeliveryMethodId, cartDeliveryGroupId);
            
            
            integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;

        } catch (DmlException de) {

            Integer numErrors = de.getNumDml();
            String errorMessage = 'There were ' + numErrors + ' errors when trying to insert the charge in the CartItem: ';
            for(Integer errorIdx = 0; errorIdx < numErrors; errorIdx++) {
                errorMessage += 'Field Names = ' + de.getDmlFieldNames(errorIdx);
                errorMessage += 'Message = ' + de.getDmlMessage(errorIdx);
                errorMessage += ' , ';
            }
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                errorMessage,
                jobInfo,
                cartId
            );

        }catch(exception e){
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                'An exception of type ' + e.getTypeName() + ' has occurred: ' + e.getMessage(),
                jobInfo,
                cartId
            );
        }
        return integStatus;
    }

    private sfdc_checkout.IntegrationStatus integrationStatusFailedWithCartValidationOutputError(

        sfdc_checkout.IntegrationStatus integrationStatus, String errorMessage, sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {

            integrationStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            CartValidationOutput cartValidationError = new CartValidationOutput(

                BackgroundOperationId = jobInfo.jobId,
                CartId = cartId,
                Level = 'Error',
                Message = errorMessage.left(255),
                Name = (String)cartId + ':' + jobInfo.jobId,
                RelatedEntityId = cartId,
                Type = 'Shipping'

            );

            insert(cartValidationError);
            return integrationStatus;
    }

    private void populateCartDeliveryGroupMehodWithShippingOptions(Id cartDeliveryGroupId,
                                                                  Id deliveryMethodId,
                                                                  Id webCartId){
        /*
            Alterar External provider, name e shipping fee
            caso você desejar nome de frete e taxa diferentes
            Neste exemplo, estou usando apenas 1 delivery method
            com custo fixo de 20.00
        */
        CartDeliveryGroupMethod cartDeliveryGroupMethod = new CartDeliveryGroupMethod(
            CartDeliveryGroupId = cartDeliveryGroupId,
            DeliveryMethodId = deliveryMethodId,
            ExternalProvider = 'Default',
            Name = 'Método de Envio Padrão',
            ShippingFee = 20.00,
            WebCartId = webCartId
        );
            insert(cartDeliveryGroupMethod);
        
    }

    private Id getShippingChargeProduct2Id(Id orderDeliveryMethodId) {
        
        List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT ProductId FROM OrderDeliveryMethod WHERE Id = :orderDeliveryMethodId];
        return orderDeliveryMethods[0].ProductId;
    }
    
    private Id getDefaultOrderDeliveryMethod() {
        String defaultDeliveryMethodName = 'Default Delivery Method';
        Id defaultDeliveryMethodId = null;
        Id product2IdForThisDeliveryMethod = getDefaultShippingChargeProduct2Id();

        
        List<OrderDeliveryMethod> defaultOrderDeliveryMethods = [SELECT Id, ProductId FROM OrderDeliveryMethod WHERE Name = :defaultDeliveryMethodName];
        if (defaultOrderDeliveryMethods.isEmpty()) {
            OrderDeliveryMethod defaultOrderDeliveryMethod = new OrderDeliveryMethod(
                Name = defaultDeliveryMethodName,
                isActive = true,
                ProductId = product2IdForThisDeliveryMethod
            );
            insert(defaultOrderDeliveryMethod);
            defaultDeliveryMethodId = defaultOrderDeliveryMethod.Id;
        }
        else {
            
            OrderDeliveryMethod defaultOrderDeliveryMethod = defaultOrderDeliveryMethods[0];
            if (defaultOrderDeliveryMethod.ProductId == null) {
                defaultOrderDeliveryMethod.ProductId = product2IdForThisDeliveryMethod;
                update(defaultOrderDeliveryMethod);
                defaultDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
            else {
                defaultDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
        }
        
        return defaultDeliveryMethodId;
    }
    
    private Id getDefaultShippingChargeProduct2Id() {
      
        String shippingChargeProduct2Name = 'Shipping Charge for this delivery method';
        List<Product2> shippingChargeProducts = [SELECT Id FROM Product2 WHERE Name = :shippingChargeProduct2Name];
        if (shippingChargeProducts.isEmpty()) {
            Product2 shippingChargeProduct = new Product2(
                isActive = true,
                Name = shippingChargeProduct2Name
            );
            insert(shippingChargeProduct);
            return shippingChargeProduct.Id;
        }
        else {
            return shippingChargeProducts[0].Id;
        }
    }
    
    private void addOrderDeliveryMethodToCartDeliveryGroup(Id someOrderDeliveryMethodId, Id someCartDeliveryGroupId) {       
        
        CartDeliveryGroup cartDeliveryGroup = [SELECT Id, DeliveryMethodId FROM CartDeliveryGroup WHERE Id= :someCartDeliveryGroupId][0];
        cartDeliveryGroup.DeliveryMethodId = someOrderDeliveryMethodId;
        update cartDeliveryGroup;
    }

}
