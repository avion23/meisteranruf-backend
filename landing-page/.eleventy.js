module.exports = function(eleventyConfig) {
    // Copy static assets
    eleventyConfig.addPassthroughCopy("src/assets");
    eleventyConfig.addPassthroughCopy("src/images");
    
    // Watch targets for development
    eleventyConfig.addWatchTarget("src/_data/");
    eleventyConfig.addWatchTarget("src/_includes/");
    
    return {
        dir: {
            input: "src",
            output: "_site",
            includes: "_includes",
            layouts: "_layouts",
            data: "_data"
        },
        pathPrefix: "/",  // Ensure relative paths work
        htmlTemplateEngine: "njk",
        markdownTemplateEngine: "njk"
    };
};
