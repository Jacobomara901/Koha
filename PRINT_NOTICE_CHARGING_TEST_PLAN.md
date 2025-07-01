# 🧪 Print Notice Charging - Complete Testing Plan

## **Prerequisites**
- Staff account with `manage_sysprefs` and `edit_borrowers` permissions
- Access to Koha staff interface and OPAC
- Test library environment (development/staging)

---

## **Phase 1: System Configuration (Frontend Only)**

### **Step 1.1: Enable Print Notice Charging**
1. **Navigate:** Administration → System Preferences → Patrons
2. **Find:** `PrintNoticeCharging` preference
3. **Set:** Enable
4. **Save**

### **Step 1.2: Set Charge Amount**
1. **Find:** `PrintNoticeChargeAmount` preference
2. **Set:** `0.50` (or desired test amount)
3. **Save**

### **Step 1.3: Enable Print Transport (KEY STEP!)**
🎯 **This is the crucial step that enables print messaging preferences:**

1. **Navigate:** Administration → Patron categories
2. **Edit** any existing category (e.g., "Adult", "Student")
3. **Scroll to:** "Default messaging preferences for this patron category"
4. **Find "Item due" row**
5. **Check the "Print" checkbox** ✅
6. **Save** the category

**Result:** This automatically creates the `message_transports` configuration needed for print messaging preferences to appear.

---

## **Phase 2: Test Data Setup**

### **Step 2.1: Create Test Patrons**
Create **2 test patrons** with different email configurations:

**Patron A: "Print User"**
- Name: Test Printuser
- Category: Same as configured in Step 1.3
- **Email:** Leave blank or delete existing email
- **Notes:** "Test patron for print notice charges"

**Patron B: "Email User"**
- Name: Test Emailuser
- Category: Same as configured in Step 1.3
- **Email:** test@example.com
- **Notes:** "Test patron for email notices (no charges)"

### **Step 2.2: Configure Messaging Preferences**

**For Patron A (Print User):**
1. **Edit patron** → **Messaging preferences**
2. **Verify:** Print column is now visible ✅
3. **Item due:** Check **Print** ✅
4. **Save**

**For Patron B (Email User):**
1. **Edit patron** → **Messaging preferences**
2. **Item due:** Check **Email** ✅
3. **Save**

### **Step 2.3: Setup Test Items**
1. **Create/find 2 test items**
2. **Check out** one item to each patron
3. **Set due dates** to yesterday (make overdue)

---

## **Phase 3: Execute Test Scenarios**

### **Scenario 1: Generate Overdue Notices**
1. **Navigate:** Tools → Overdue notice/status triggers
2. **Run overdue notices** for your test branch
3. **OR** use command line: `misc/cronjobs/overdue_notices.pl`

### **Scenario 2: Process Print Notices**
1. **Navigate:** Tools → Batch patron modification
2. **OR** use command line: `misc/cronjobs/gather_print_notices.pl /tmp/test`

---

## **Phase 4: Verify Results**

### **Verification 4.1: Check Patron Accounts**

**Patron A (Print User) - Should Have Charges:**
1. **Go to patron account** → **Account** tab
2. **Expected:** £0.50 charge with description "Print notice: DUE" ✅
3. **Status:** Outstanding debt

**Patron B (Email User) - Should Have No Charges:**
1. **Go to patron account** → **Account** tab
2. **Expected:** No print notice charges ✅
3. **Status:** Clean account

### **Verification 4.2: Check Notice Queue**
1. **Navigate:** Tools → Notice and slips → Message queue
2. **Search:** Both patrons
3. **Expected Results:**
   - **Patron A:** Notice with `message_transport_type = 'print'`
   - **Patron B:** Notice with `message_transport_type = 'email'`

### **Verification 4.3: Test OPAC Warnings**

**Patron A (No Email) OPAC Login:**
1. **Log into OPAC** as Patron A
2. **Navigate:** Your account → Messaging
3. **Expected:** Prominent warning about print charges ✅
4. **Text should include:** "Print notices incur a charge of £0.50"

**Patron B (With Email) OPAC Login:**
1. **Log into OPAC** as Patron B
2. **Navigate:** Your account → Messaging
3. **Expected:** No print charge warnings (has email) ✅

---

## **Phase 5: Edge Case Testing**

### **Test 5.1: Disable Charging**
1. **Set:** `PrintNoticeCharging` = Disable
2. **Repeat** notice generation process
3. **Expected:** No new charges applied ✅

### **Test 5.2: Different Charge Amount**
1. **Set:** `PrintNoticeChargeAmount` = 1.25
2. **Generate** new overdue notices
3. **Expected:** New charges at £1.25 ✅

### **Test 5.3: Skip Charges Flag** (Command Line)
```bash
misc/cronjobs/gather_print_notices.pl /tmp/test --skip-charges
```
**Expected:** Print notices processed but no charges applied ✅

---

## **Phase 6: Cleanup**

### **Reset Test Environment**
1. **Pay off** test patron charges (if needed)
2. **Return** test items
3. **Delete** test patrons (optional)
4. **Reset** system preferences to production values

---

## **🔍 Troubleshooting Guide**

### **Print Checkboxes Still Not Visible?**
- ✅ Verify you configured category defaults in Step 1.3
- ✅ Check patron is in the correct category
- ✅ Try editing a different patron category
- ✅ Clear browser cache

### **No Charges Applied?**
- ✅ Verify `PrintNoticeCharging` = Enable
- ✅ Check patron has print messaging preferences enabled
- ✅ Confirm overdue notices were generated
- ✅ Check gather_print_notices.pl was run

### **Wrong Charge Amount?**
- ✅ Check `PrintNoticeChargeAmount` system preference
- ✅ Verify currency formatting in account display

---

## **📊 Expected Test Results Summary**

| Test Scenario | Patron A (Print) | Patron B (Email) |
|---------------|------------------|------------------|
| **Messaging Preferences** | Print checkbox visible ✅ | Print checkbox visible ✅ |
| **OPAC Warnings** | Charge warning shown ✅ | No warning (has email) ✅ |
| **Account Charges** | £0.50 charge applied ✅ | No charges ✅ |
| **Notice Transport** | print transport ✅ | email transport ✅ |

---

## **🎯 Success Criteria**

✅ **Configuration:** Print transport enabled via frontend only
✅ **Messaging:** Print checkboxes appear and function correctly
✅ **Charging:** Charges applied only to print notice users
✅ **OPAC:** Appropriate warnings displayed
✅ **Accounts:** Charges appear with correct descriptions
✅ **Flexibility:** Feature can be enabled/disabled via preferences

---

## **📝 Notes for Testers**

- **Timing:** Allow 5-10 minutes between notice generation and charge application
- **Permissions:** Ensure test account has required permissions
- **Environment:** Test in development environment first
- **Documentation:** Screenshot key results for documentation
- **Rollback:** Be prepared to disable feature if issues arise

**Total Testing Time:** ~30 minutes for complete workflow