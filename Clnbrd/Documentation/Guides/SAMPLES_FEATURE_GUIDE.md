# Clnbrd Samples Feature Guide

## 🎯 **New "View Samples" Feature**

I've added a comprehensive "View Samples" feature to your Clnbrd app that shows users exactly how each cleaning rule works with before/after examples.

## ✅ **What's New:**

### **1. "View Samples" Menu Item**
- ✅ Added to the main menu bar
- ✅ Shows comprehensive before/after examples
- ✅ Professional window with scrollable content
- ✅ Interactive test feature

### **2. Visual Before/After Examples**
Each cleaning rule now shows:
- **Rule Title** - Clear name of the rule
- **Description** - What the rule does
- **BEFORE** - Original text with issues
- **AFTER** - Cleaned text result
- **Visual Arrow** - Shows the transformation

### **3. Interactive Test Feature**
- ✅ **"Test Sample Text" button** - Users can test their own text
- ✅ **Input field** - Enter custom text to test
- ✅ **Real-time cleaning** - See results immediately
- ✅ **Copy result** - Copy cleaned text to clipboard

## 📱 **User Experience:**

### **Accessing Samples:**
1. Click Clnbrd menu bar icon
2. Select "View Samples"
3. See comprehensive examples window

### **Testing Your Own Text:**
1. In samples window, click "Test Sample Text"
2. Enter your text in the input field
3. Click "Test Cleaning Rules"
4. See the cleaned result
5. Click "Copy Result" to copy to clipboard

## 🔧 **Sample Rules Shown:**

### **Built-in Rules:**
1. **Remove Em Dashes** - `Hello—world—test` → `Hello, world, test`
2. **Normalize Spaces** - `Hello    world   test` → `Hello world test`
3. **Remove Zero-Width Characters** - `Hello\u{200B}world` → `Helloworld`
4. **Normalize Line Breaks** - `Hello\r\nworld` → `Hello\nworld`
5. **Remove Smart Quotes** - `"Hello"` → `"Hello"`
6. **Remove Smart Apostrophes** - `It's` → `It's`
7. **Remove Smart Dashes** - `Hello–world` → `Hello-world`
8. **Remove Non-Breaking Spaces** - `Hello\u{00A0}world` → `Hello world`
9. **Remove Soft Hyphens** - `Hello\u{00AD}world` → `Helloworld`
10. **Remove Word Joiners** - `Hello\u{2060}world` → `Helloworld`

### **Custom Rules:**
- Shows example of custom find-and-replace rules
- Explains how to create them in Settings

## 🎨 **Visual Design:**

### **Professional Layout:**
- **Scrollable window** - Handles many examples
- **Card-based design** - Each rule in its own container
- **Monospace font** - Shows exact text transformations
- **Color coding** - Before/after sections clearly distinguished
- **Rounded corners** - Modern, polished appearance

### **Interactive Elements:**
- **Test button** - Prominent call-to-action
- **Input field** - Pre-filled with example text
- **Copy button** - Easy result copying
- **Notifications** - Confirms when text is copied

## 💡 **Benefits:**

### **For Users:**
- **Clear understanding** - See exactly what each rule does
- **Confidence** - Know what to expect from cleaning
- **Testing** - Try rules on their own text
- **Learning** - Understand invisible character issues

### **For You:**
- **Reduced support** - Users understand the app better
- **Higher adoption** - Users see the value of each rule
- **Professional appearance** - Polished, comprehensive help
- **User engagement** - Interactive testing keeps users engaged

## 🚀 **Technical Implementation:**

### **Window Management:**
- **Resizable window** - Users can adjust size
- **Scrollable content** - Handles many examples
- **Auto-layout** - Responsive design
- **Memory efficient** - Proper cleanup

### **Text Processing:**
- **Real-time cleaning** - Uses actual cleaning rules
- **Unicode support** - Handles all character types
- **Clipboard integration** - Seamless copying

### **User Interface:**
- **Native macOS** - Uses system UI elements
- **Accessibility** - Proper labels and descriptions
- **Keyboard navigation** - Full keyboard support

## 📝 **Example User Flow:**

```
User clicks "View Samples"
↓
Sees comprehensive examples window
↓
Scrolls through all cleaning rules
↓
Clicks "Test Sample Text"
↓
Enters: "Hello—world    test"
↓
Clicks "Test Cleaning Rules"
↓
Sees result: "Hello, world test"
↓
Clicks "Copy Result"
↓
Gets notification: "Copied!"
```

## 🎉 **Result:**

Your users now have a comprehensive, interactive way to understand exactly how Clnbrd's cleaning rules work. This will:

- **Reduce confusion** about what each rule does
- **Increase user confidence** in the app
- **Provide hands-on testing** of cleaning rules
- **Create a professional, polished experience**

The samples feature makes Clnbrd much more user-friendly and professional! 🚀
