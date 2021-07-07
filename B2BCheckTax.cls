global class B2BCheckTax implements sfdc_checkout.CartTaxCalculations {

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {

        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();


        /*
            Não implementei essa classe pois neste momento não precisamos realizar uma integração para taxas.
            apenas coloquei para que o status de integração retorne TRUE, resolvendo o problema de checkout do B2B.
            
        */
        try{

            integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;

        }catch(Exception e){

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
                Type = 'Taxes'
            );
            insert(cartValidationError);
            return integrationStatus;
    }

}
