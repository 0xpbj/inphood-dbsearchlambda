//Lambda OEmbed Configuration
https://api.inphood.com/oembed/* OK

//Consumer Request to label.inphood.com
http://label.inphood.com/oembed/?url=http%3A//label.inphood.com/?user=test&label=-KeuRz0ubjnQVkJCmGDH
//label.inphood.com to api gateway
https://api.inphood.com/oembed/?url=http%3A%2F%2Fwww.label.inphood.com%2F%3Fquery%26user%3Dtest%26label%3D-KeuRz0ubjnQVkJCmGDH

//Lambda Response
{"version":"1.0","type":"rich","width":400,"height":600,"title":"-KeuRz0ubjnQVkJCmGDH","url":"http://label.inphood.com/?embed=true&user=test&label=-KeuRz0ubjnQVkJCmGDH","author_name":"test","author_url":"http://www.label.inphood.com/","provider_name":"inphood","provider_url":"http://www.inphood.com/","html":"<object width=\"400\" height=\"600\"><embed src=http://label.inphood.com/?embed=true&user=test&label=-KeuRz0ubjnQVkJCmGDHwidth=\"400\" height=\"600\"></embed></object>"}