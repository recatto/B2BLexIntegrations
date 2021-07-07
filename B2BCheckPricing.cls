global class B2BCheckPricing implements sfdc_checkout.CartPriceCalculations {

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {

        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();
        try{

            /*
                Como não iremos utilizar uma checagem de preço em serviço externo
                apenas fiz uma comparação para saber se os itens do carrinho são
                maiores que zero. Caso seja, o status de integração retorna true.
            */

            List<CartItem> listCartItem = [SELECT Sku, SalesPrice FROM CartItem WHERE CartId = :cartId AND Type = 'Product'];
            for (CartItem cartItem : listCartItem) {
                if (cartItem.SalesPrice > 0.00){
                    integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;
                }else{
                    String errorMessage = 'The sale price of this product has encountered an error. Please contact Admin.';
                       return integrationStatusFailedWithCartValidationOutputError(
                           integStatus,
                           errorMessage,
                           jobInfo,
                           cartId
                       );
                }
            }
        }
        catch(Exception e){
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
                Type = 'Pricing'
            );
            insert(cartValidationError);
            return integrationStatus;
    }
}
