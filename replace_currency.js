const fs = require('fs');
const glob = require('glob');

const paths = [
    'lib/screens/admin_screen.dart', 
    'lib/screens/client_screen.dart', 
    'lib/scan_result_page.dart', 
    'lib/screens/admin_screen_new.dart',
    'lib/screens/business_admin_screen.dart',
    'lib/screens/admin_screen_original.dart',
];

paths.forEach(p => {
    if (!fs.existsSync(p)) {
        console.log('Skipping ' + p + ' (not found)');
        return;
    }
    let content = fs.readFileSync(p, 'utf8');
    
    // Replace \$\d+,\d+ or \$\d+.\d+
    let replaced = content.replace(/\\\$\s*([\d,]+(\.\d{2})?)/g, (match, amountStr) => {
        let stripped = amountStr.replace(/,/g, '');
        let num = parseFloat(stripped);
        if (isNaN(num)) return match;
        
        let newAmount = Math.round(num * 55);
        return '₱' + newAmount.toLocaleString('en-US');
    });

    // Replace explicit "USD" with "PHP"
    replaced = replaced.replace(/\bUSD\b/g, 'PHP');
    
    if (content !== replaced) {
        fs.writeFileSync(p, replaced, 'utf8');
        console.log('Updated ' + p);
    }
});
