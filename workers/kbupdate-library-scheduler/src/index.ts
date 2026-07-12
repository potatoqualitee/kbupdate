import { checkAndDispatch } from "./scheduler";

export default {
  async scheduled(controller, env): Promise<void> {
    try {
      const result = await checkAndDispatch(env, new Date(controller.scheduledTime));
      console.log(JSON.stringify({ event: "catalog-check", ...result }));
    } catch (error) {
      console.error(
        JSON.stringify({
          event: "catalog-check-failed",
          message: error instanceof Error ? error.message : String(error),
        }),
      );
      throw error;
    }
  },
} satisfies ExportedHandler<Env>;
