
const { DefaultAzureCredential } = require("@azure/identity");
const { LogsIngestionClient } = require("@azure/monitor-ingestion");

module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');
    context.log("Headers:");
    context.log(req.headers);
    context.log("Body:");
    context.log(req.body);
    let responseMessage = ""
    let status = 200
    if (req.body && req.body.instant){
        const logsIngestionEndpoint = process.env.DATA_COLLECTION_ENDPOINT 
        const ruleId = process.env.DATA_IMMUTABLE_ID
        const streamName = process.env.DATA_STREAM
        const credential = new DefaultAzureCredential();
        const client = new LogsIngestionClient(logsIngestionEndpoint, credential);

        const logs = [
            {
                "Time": new Date (req.body.instant.epochSecond * 1000 + req.body.instant.nanoOfSecond / 1000000 ),
                "Computer": req.headers["x-client-ip"],
                "AdditionalContext": req.body
            }
        ]
        const result = await client.upload(ruleId, streamName, logs);
        context.log(result)
        if (result.status !== "Success") {
            context.log("Some logs have failed to complete ingestion. Upload status=", result.status);
            
            
        }

    }else {
        const name = (req.query.name || (req.body && req.body.name));
        responseMessage = name
            ? "Hello, " + name + ". This HTTP triggered function executed successfully."
            : "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.";
        if ( name && name.toLowerCase().indexOf('fail') > -1){
            context.log('name contains fail...')
            throw new Error('This is an error because the name contains fail...')
        }
    }

    context.res = {
        status: status,
        body: responseMessage
    };

    
}