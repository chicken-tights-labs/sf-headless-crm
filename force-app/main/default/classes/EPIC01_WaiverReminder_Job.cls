/**
 * EPIC01-US-005: daily job for waiver reminders.
 * Register once (Developer Console / sf apex run):
 *   System.schedule('EPIC01 Waiver Reminder', '0 0 8 * * ?', new EPIC01_WaiverReminder_Job());
 */
public with sharing class EPIC01_WaiverReminder_Job implements Schedulable {
    public void execute(SchedulableContext ctx) {
        EPIC01_MemberOnboarding_Service.runWaiverReminderJob();
    }
}
