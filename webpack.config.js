const path = require('path')

module.exports = {

	module: {
		rules: [
			{
				test: /\.coffee/,
				use: [
					{ loader: "header-fix" },
					{ loader: "coffee-loader" },
				],
			},
		],
	},

	entry: './src/web/index/$.coffee',
	output: {
		path: path.resolve(__dirname, 'web/static'),
		filename: 'index.js'
	},

	resolveLoader: {
		alias: {
			"header-fix": path.resolve(__dirname, "webpack.header-fix.js"),
		},
	},

}