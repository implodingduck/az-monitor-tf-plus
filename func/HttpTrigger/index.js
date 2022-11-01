
const { DefaultAzureCredential } = require("@azure/identity");

module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');
    context.log(req.headers)
    context.log(req.body);
    if (req.body && req.body.instant){
        const credential = new DefaultAzureCredential();
        context.log(credential)
    }else {
        const name = (req.query.name || (req.body && req.body.name));
    const responseMessage = name
        ? "Hello, " + name + ". This HTTP triggered function executed successfully."
        : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";
    if ( name && name.toLowerCase().indexOf('fail') > -1){
        context.log('name contains fail...')
        throw new Error('This is an error because the name contains fail...')
    }
    
    context.res = {
        // status: 200, /* Defaults to 200 */
        body: responseMessage
    };
    }
    
}